-- ============================================================
-- MIGRATION 092: Store school_id on pending_enrollments
--
-- Problem: When a teacher bulk-adds students by email, the
-- school that those students should join was determined by the
-- trigger (auto_assign_student_to_school), which uses
-- classes.school_id.  If the class has no school_id, or the
-- teacher is operating in a different school context, the
-- students end up in the wrong school (or no school at all).
--
-- Fix:
--   1. Add nullable school_id column to pending_enrollments
--      so the teacher's currently-selected school is captured
--      at the moment of adding students.
--   2. Update add_pending_enrollments to accept and store
--      p_school_id (optional, defaults to classes.school_id).
--   3. Update process_pending_enrollments to insert directly
--      into school_students using the stored school_id when
--      present (the class_members trigger still fires as a
--      fallback using classes.school_id).
-- ============================================================

-- ============================================================
-- 1. Add school_id column to pending_enrollments
-- ============================================================
ALTER TABLE pending_enrollments
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_pending_enrollments_school_id
  ON pending_enrollments(school_id);

-- ============================================================
-- 2. Update add_pending_enrollments
--    New optional param: p_school_id (falls back to
--    classes.school_id when NULL).
-- ============================================================
CREATE OR REPLACE FUNCTION add_pending_enrollments(
  p_class_id  UUID,
  p_emails    TEXT[],
  p_school_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id        UUID;
  v_user_id           UUID;
  v_resolved_school   UUID;
  v_email             TEXT;
  v_added_count       INTEGER := 0;
  v_skipped_count     INTEGER := 0;
  v_already_enrolled  INTEGER := 0;
BEGIN
  v_user_id := auth.uid();

  -- Verify the class exists and get its teacher + school
  SELECT teacher_id, school_id
  INTO   v_teacher_id, v_resolved_school
  FROM   classes
  WHERE  id = p_class_id;

  IF v_teacher_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  -- Authorization: class teacher or admin
  IF v_teacher_id != v_user_id AND NOT is_admin() THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You do not have permission to add students to this class'
    );
  END IF;

  -- Prefer the explicitly supplied school_id; fall back to the class's school
  IF p_school_id IS NOT NULL THEN
    v_resolved_school := p_school_id;
  END IF;

  FOREACH v_email IN ARRAY p_emails
  LOOP
    v_email := LOWER(TRIM(v_email));

    IF v_email = '' OR v_email IS NULL THEN
      CONTINUE;
    END IF;

    -- Already enrolled as an active member?
    IF EXISTS (
      SELECT 1
      FROM   class_members cm
      JOIN   users u ON u.id = cm.user_id
      WHERE  cm.class_id = p_class_id
        AND  LOWER(u.email) = v_email
    ) THEN
      v_already_enrolled := v_already_enrolled + 1;
      CONTINUE;
    END IF;

    -- Already in pending enrollments?
    IF EXISTS (
      SELECT 1
      FROM   pending_enrollments
      WHERE  class_id = p_class_id
        AND  LOWER(email) = v_email
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    INSERT INTO pending_enrollments (class_id, email, added_by, school_id)
    VALUES (p_class_id, v_email, v_user_id, v_resolved_school);

    v_added_count := v_added_count + 1;
  END LOOP;

  RETURN json_build_object(
    'success',          true,
    'added',            v_added_count,
    'skipped',          v_skipped_count,
    'already_enrolled', v_already_enrolled,
    'message',          format(
      'Added %s email(s). %s already pending. %s already enrolled.',
      v_added_count, v_skipped_count, v_already_enrolled
    )
  );
END;
$$;

-- Drop the old 2-param overload so PostgREST doesn't see ambiguity
DROP FUNCTION IF EXISTS public.add_pending_enrollments(UUID, TEXT[]);

GRANT EXECUTE ON FUNCTION add_pending_enrollments(UUID, TEXT[], UUID) TO authenticated;

-- ============================================================
-- 3. Update process_pending_enrollments
--    After inserting into class_members (which fires the
--    auto_assign_student_to_school trigger using classes.school_id),
--    also insert directly into school_students using
--    pe.school_id when it differs or the class has no school_id.
-- ============================================================
CREATE OR REPLACE FUNCTION process_pending_enrollments(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_email    TEXT;
  v_pending       RECORD;
  v_enrolled      INTEGER := 0;
  v_class_names   TEXT[]  := ARRAY[]::TEXT[];
BEGIN
  SELECT email INTO v_user_email FROM users WHERE id = p_user_id;

  IF v_user_email IS NULL THEN
    RETURN json_build_object(
      'success',        false,
      'message',        'User not found',
      'enrolled_count', 0
    );
  END IF;

  FOR v_pending IN
    SELECT pe.id,
           pe.class_id,
           pe.school_id,
           c.name AS class_name
    FROM   pending_enrollments pe
    JOIN   classes c ON c.id = pe.class_id
    WHERE  LOWER(pe.email) = LOWER(v_user_email)
      AND  c.archived = false
  LOOP
    -- Guard: skip if already a member
    IF NOT EXISTS (
      SELECT 1 FROM class_members
      WHERE  class_id = v_pending.class_id
        AND  user_id  = p_user_id
    ) THEN
      -- Insert into class_members; the trigger auto_assign_student_to_school
      -- will insert into school_students using classes.school_id.
      INSERT INTO class_members (class_id, user_id, joined_at)
      VALUES (v_pending.class_id, p_user_id, NOW());

      -- Additionally, if a specific school was captured at enrollment time,
      -- ensure the student is in that school (handles cases where the
      -- class.school_id is NULL or differs from the teacher's selected school).
      IF v_pending.school_id IS NOT NULL THEN
        INSERT INTO school_students (school_id, user_id)
        VALUES (v_pending.school_id, p_user_id)
        ON CONFLICT (school_id, user_id) DO NOTHING;
      END IF;

      v_enrolled    := v_enrolled + 1;
      v_class_names := array_append(v_class_names, v_pending.class_name);
    END IF;

    DELETE FROM pending_enrollments WHERE id = v_pending.id;
  END LOOP;

  RETURN json_build_object(
    'success',        true,
    'enrolled_count', v_enrolled,
    'class_names',    v_class_names,
    'message',        CASE
      WHEN v_enrolled > 0
        THEN format('Automatically enrolled in %s class(es)', v_enrolled)
      ELSE 'No pending enrollments found'
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION process_pending_enrollments(UUID) TO authenticated;
