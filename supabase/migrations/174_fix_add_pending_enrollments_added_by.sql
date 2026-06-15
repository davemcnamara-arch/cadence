-- ============================================================
-- MIGRATION 174: Fix add_pending_enrollments NOT NULL violation
--
-- Problem: The version of add_pending_enrollments introduced in
-- migration 144 (co-teacher support) dropped the `added_by` and
-- `school_id` columns from the INSERT into pending_enrollments.
-- `added_by` is NOT NULL (migration 034), so Bulk Add Students
-- failed for any email that doesn't already belong to a user
-- (error 23502: null value in column "added_by" violates
-- not-null constraint).
--
-- Fix: restore added_by = auth.uid() and school_id = v_resolved_school
-- on the INSERT, matching the behaviour from migration 092.
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
  v_resolved_school   UUID;
  v_email             TEXT;
  v_added_count       INTEGER := 0;
  v_skipped_count     INTEGER := 0;
  v_already_enrolled  INTEGER := 0;
BEGIN
  -- Verify the class exists and get its school
  SELECT school_id
  INTO   v_resolved_school
  FROM   classes
  WHERE  id = p_class_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  IF NOT is_class_teacher_or_coteacher(p_class_id) AND NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'You do not have permission to add students to this class');
  END IF;

  -- Prefer explicitly supplied school_id; fall back to the class's school
  IF p_school_id IS NOT NULL THEN
    v_resolved_school := p_school_id;
  END IF;

  FOREACH v_email IN ARRAY p_emails
  LOOP
    v_email := LOWER(TRIM(v_email));

    IF v_email = '' OR v_email IS NULL THEN
      CONTINUE;
    END IF;

    -- Already a class member?
    IF EXISTS (
      SELECT 1
      FROM class_members cm
      JOIN users u ON u.id = cm.user_id
      WHERE cm.class_id = p_class_id AND LOWER(u.email) = v_email
    ) THEN
      v_already_enrolled := v_already_enrolled + 1;
      CONTINUE;
    END IF;

    -- Already has a pending enrollment for this class?
    IF EXISTS (
      SELECT 1 FROM pending_enrollments
      WHERE class_id = p_class_id AND LOWER(email) = v_email
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    -- If the user already exists, enroll them directly
    IF EXISTS (SELECT 1 FROM users WHERE LOWER(email) = v_email AND role = 'student') THEN
      INSERT INTO class_members (class_id, user_id)
      SELECT p_class_id, u.id
      FROM users u
      WHERE LOWER(u.email) = v_email AND u.role = 'student'
      ON CONFLICT (class_id, user_id) DO NOTHING;

      IF v_resolved_school IS NOT NULL THEN
        INSERT INTO school_students (school_id, user_id)
        SELECT v_resolved_school, u.id
        FROM users u
        WHERE LOWER(u.email) = v_email AND u.role = 'student'
        ON CONFLICT (school_id, user_id) DO NOTHING;
      END IF;

      v_added_count := v_added_count + 1;
    ELSE
      INSERT INTO pending_enrollments (class_id, email, added_by, school_id)
      VALUES (p_class_id, v_email, auth.uid(), v_resolved_school)
      ON CONFLICT (class_id, email) DO NOTHING;

      v_added_count := v_added_count + 1;
    END IF;
  END LOOP;

  RETURN json_build_object(
    'success',          true,
    'added_count',      v_added_count,
    'skipped_count',    v_skipped_count,
    'already_enrolled', v_already_enrolled,
    'message',          format('%s student(s) added', v_added_count)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION add_pending_enrollments(UUID, TEXT[], UUID) TO authenticated;
