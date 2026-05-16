-- ============================================================
-- MIGRATION 144: Class co-teaching and ownership handoff
--
-- Adds two new features:
--   1. Co-teaching: class owners can add peer teachers as
--      co-teachers, giving them full management access to the
--      class (edit, roster, students, archive, export).
--   2. Class handoff: owners can transfer a class to another
--      teacher at the same school — a full, one-way transfer
--      with no retained access.
--
-- New objects:
--   - class_co_teachers table (junction: class ↔ teacher)
--   - is_class_co_teacher(class_id)          SECURITY DEFINER
--   - is_class_teacher_or_coteacher(class_id) SECURITY DEFINER
--   - RLS policies: co-teacher SELECT/UPDATE on classes
--   - get_class_co_teachers(class_id)        RPC
--   - add_co_teacher(class_id, teacher_id)   RPC
--   - remove_co_teacher(class_id, teacher_id) RPC
--   - transfer_class_ownership(class_id, new_teacher_id) RPC
--
-- Updated RPCs (co-teacher access):
--   - get_class_students
--   - get_class_timeline
--   - remove_student_from_class
--   - update_student_name
--   - transfer_student_between_classes
--   - get_pending_enrollments
--   - remove_pending_enrollment
--   - add_pending_enrollments
--
-- Updated function:
--   - get_teacher_classes() — now includes co-taught classes
--     with is_co_teacher: true in the result
-- ============================================================


-- ============================================================
-- 1. class_co_teachers junction table
-- ============================================================
CREATE TABLE IF NOT EXISTS class_co_teachers (
  class_id   UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  added_at   TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (class_id, teacher_id)
);

ALTER TABLE class_co_teachers ENABLE ROW LEVEL SECURITY;

-- Needed so authenticated users can query the table inside SECURITY DEFINER functions.
-- Direct table access is gated by the policies below.
GRANT SELECT, INSERT, DELETE ON class_co_teachers TO authenticated;


-- ============================================================
-- 2. RLS policies on class_co_teachers
-- ============================================================

-- The class owner can view, add, and remove co-teachers for their own classes
CREATE POLICY "Class owners can manage co-teachers" ON class_co_teachers
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM classes
    WHERE id = class_id AND teacher_id = auth.uid()
  )
);

-- A co-teacher can view their own record (so they know which classes they co-teach)
CREATE POLICY "Co-teachers can view own records" ON class_co_teachers
FOR SELECT USING (teacher_id = auth.uid());


-- ============================================================
-- 3. Helper: is_class_co_teacher(p_class_id)
--    SECURITY DEFINER to avoid RLS recursion (classes policy
--    calls this; this only reads class_co_teachers directly).
-- ============================================================
CREATE OR REPLACE FUNCTION is_class_co_teacher(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM class_co_teachers
    WHERE class_id = p_class_id AND teacher_id = auth.uid()
  )
$$;

GRANT EXECUTE ON FUNCTION is_class_co_teacher(UUID) TO authenticated;


-- ============================================================
-- 4. Helper: is_class_teacher_or_coteacher(p_class_id)
--    Returns true if the caller is the owner OR a co-teacher.
--    Does NOT include admins — callers add that check separately
--    so the function stays purpose-focused.
-- ============================================================
CREATE OR REPLACE FUNCTION is_class_teacher_or_coteacher(p_class_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT
    EXISTS (SELECT 1 FROM classes WHERE id = p_class_id AND teacher_id = auth.uid())
    OR
    EXISTS (SELECT 1 FROM class_co_teachers WHERE class_id = p_class_id AND teacher_id = auth.uid())
$$;

GRANT EXECUTE ON FUNCTION is_class_teacher_or_coteacher(UUID) TO authenticated;


-- ============================================================
-- 5. RLS: co-teachers can SELECT classes they co-teach
-- ============================================================
CREATE POLICY "Co-teachers can view their classes" ON classes
FOR SELECT USING (is_class_co_teacher(id));


-- ============================================================
-- 6. RLS: co-teachers can UPDATE classes they co-teach
--    (edit name/year_level, set archived, etc.)
-- ============================================================
CREATE POLICY "Co-teachers can update their classes" ON classes
FOR UPDATE USING (is_class_co_teacher(id));


-- ============================================================
-- 7. get_class_co_teachers RPC
--    Returns the list of co-teachers for a class.
--    Accessible to: class owner, co-teachers, admins.
-- ============================================================
CREATE OR REPLACE FUNCTION get_class_co_teachers(p_class_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSON;
BEGIN
  IF NOT is_class_teacher_or_coteacher(p_class_id) AND NOT is_admin() THEN
    RETURN '[]'::json;
  END IF;

  SELECT COALESCE(
    json_agg(
      json_build_object(
        'teacher_id', u.id,
        'name',       u.name,
        'email',      u.email,
        'added_at',   ct.added_at
      )
      ORDER BY u.name
    ),
    '[]'::json
  )
  INTO v_result
  FROM class_co_teachers ct
  JOIN users u ON u.id = ct.teacher_id
  WHERE ct.class_id = p_class_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_class_co_teachers(UUID) TO authenticated;


-- ============================================================
-- 8. add_co_teacher RPC
--    Allowed: class owner or admin.
--    The co-teacher must share a school with the caller
--    (unless caller is admin).
-- ============================================================
CREATE OR REPLACE FUNCTION add_co_teacher(p_class_id UUID, p_teacher_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      UUID := auth.uid();
  v_class_owner_id UUID;
BEGIN
  SELECT teacher_id INTO v_class_owner_id FROM classes WHERE id = p_class_id;

  IF v_class_owner_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  IF v_caller_id != v_class_owner_id AND NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Only the class owner can add co-teachers');
  END IF;

  IF p_teacher_id = v_class_owner_id THEN
    RETURN json_build_object('success', false, 'message', 'The class owner cannot be added as a co-teacher');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_teacher_id AND role IN ('teacher', 'admin')) THEN
    RETURN json_build_object('success', false, 'message', 'That user is not a teacher');
  END IF;

  IF NOT is_admin() AND NOT teachers_share_school(v_caller_id, p_teacher_id) THEN
    RETURN json_build_object('success', false, 'message', 'Co-teachers must be at the same school');
  END IF;

  INSERT INTO class_co_teachers (class_id, teacher_id)
  VALUES (p_class_id, p_teacher_id)
  ON CONFLICT (class_id, teacher_id) DO NOTHING;

  RETURN json_build_object('success', true, 'message', 'Co-teacher added');
END;
$$;

GRANT EXECUTE ON FUNCTION add_co_teacher(UUID, UUID) TO authenticated;


-- ============================================================
-- 9. remove_co_teacher RPC
--    Allowed: class owner, the co-teacher themselves, or admin.
-- ============================================================
CREATE OR REPLACE FUNCTION remove_co_teacher(p_class_id UUID, p_teacher_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      UUID := auth.uid();
  v_class_owner_id UUID;
BEGIN
  SELECT teacher_id INTO v_class_owner_id FROM classes WHERE id = p_class_id;

  IF v_class_owner_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  IF v_caller_id != v_class_owner_id
     AND v_caller_id != p_teacher_id
     AND NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
  END IF;

  DELETE FROM class_co_teachers
  WHERE class_id = p_class_id AND teacher_id = p_teacher_id;

  RETURN json_build_object('success', true, 'message', 'Co-teacher removed');
END;
$$;

GRANT EXECUTE ON FUNCTION remove_co_teacher(UUID, UUID) TO authenticated;


-- ============================================================
-- 10. transfer_class_ownership RPC
--     Full ownership transfer — original owner loses all access.
--     Allowed: class owner or admin.
--     New owner must share a school (unless caller is admin).
-- ============================================================
CREATE OR REPLACE FUNCTION transfer_class_ownership(
  p_class_id       UUID,
  p_new_teacher_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      UUID := auth.uid();
  v_old_teacher_id UUID;
BEGIN
  SELECT teacher_id INTO v_old_teacher_id FROM classes WHERE id = p_class_id;

  IF v_old_teacher_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  IF v_caller_id != v_old_teacher_id AND NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Only the class owner can transfer ownership');
  END IF;

  IF p_new_teacher_id = v_old_teacher_id THEN
    RETURN json_build_object('success', false, 'message', 'Class is already owned by this teacher');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_new_teacher_id AND role IN ('teacher', 'admin')) THEN
    RETURN json_build_object('success', false, 'message', 'New owner must be a teacher');
  END IF;

  IF NOT is_admin() AND NOT teachers_share_school(v_caller_id, p_new_teacher_id) THEN
    RETURN json_build_object('success', false, 'message', 'New owner must be at the same school');
  END IF;

  -- If the new owner was previously a co-teacher, remove that record
  DELETE FROM class_co_teachers
  WHERE class_id = p_class_id AND teacher_id = p_new_teacher_id;

  -- Transfer ownership (old owner loses all access)
  UPDATE classes SET teacher_id = p_new_teacher_id WHERE id = p_class_id;

  RETURN json_build_object('success', true, 'message', 'Class ownership transferred');
END;
$$;

GRANT EXECUTE ON FUNCTION transfer_class_ownership(UUID, UUID) TO authenticated;


-- ============================================================
-- 11. Update class data RPCs for co-teacher access
-- ============================================================

-- 11a. get_class_students
--      Old: teacher OR class member
--      New: teacher OR co-teacher OR class member
CREATE OR REPLACE FUNCTION public.get_class_students(p_class_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_is_authorized   BOOLEAN;
  v_result          JSON;
BEGIN
  v_current_user_id := auth.uid();

  SELECT (
    is_admin()
    OR is_class_teacher_or_coteacher(p_class_id)
    OR EXISTS (
      SELECT 1 FROM class_members cm
      WHERE cm.class_id = p_class_id AND cm.user_id = v_current_user_id
    )
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this class';
  END IF;

  SELECT json_agg(
    json_build_object(
      'id',        cm.id,
      'class_id',  cm.class_id,
      'user_id',   cm.user_id,
      'joined_at', cm.joined_at,
      'users', json_build_object(
        'id',    u.id,
        'name',  u.name,
        'email', u.email
      ),
      'student_progress', (
        SELECT json_agg(
          json_build_object(
            'instrument_id',          sp.instrument_id,
            'current_level',          sp.current_level,
            'current_branch',         sp.current_branch,
            'custom_instrument_name', sp.custom_instrument_name
          )
        )
        FROM student_progress sp
        WHERE sp.user_id = u.id
      )
    )
    ORDER BY cm.joined_at ASC
  )
  INTO v_result
  FROM class_members cm
  JOIN users u ON u.id = cm.user_id
  WHERE cm.class_id = p_class_id;

  RETURN COALESCE(v_result, '[]'::json);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    RETURN '[]'::json;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_class_students(UUID) TO authenticated;


-- 11b. get_class_timeline
--      Old: teacher only
--      New: teacher or co-teacher
CREATE OR REPLACE FUNCTION get_class_timeline(p_class_id UUID)
RETURNS TABLE (
  id               UUID,
  user_id          UUID,
  song_id          UUID,
  instrument_id    UUID,
  status           TEXT,
  date_started     TIMESTAMP WITH TIME ZONE,
  date_completed   TIMESTAMP WITH TIME ZONE,
  notes            TEXT,
  student_name     TEXT,
  song_title       TEXT,
  song_artist      TEXT,
  instrument_icon  TEXT,
  instrument_name  TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_class_teacher_or_coteacher(p_class_id) AND NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this class';
  END IF;

  RETURN QUERY
  SELECT
    ss.id,
    ss.user_id,
    ss.song_id,
    ss.instrument_id,
    ss.status,
    ss.date_started,
    ss.date_completed,
    ss.notes,
    u.name  AS student_name,
    s.title AS song_title,
    s.artist AS song_artist,
    i.icon  AS instrument_icon,
    i.name  AS instrument_name
  FROM student_songs ss
  JOIN class_members cm ON ss.user_id = cm.user_id
  JOIN users u ON ss.user_id = u.id
  JOIN songs s ON ss.song_id = s.id
  JOIN instruments i ON ss.instrument_id = i.id
  WHERE cm.class_id = p_class_id
  ORDER BY ss.date_started DESC
  LIMIT 20;
END;
$$;

GRANT EXECUTE ON FUNCTION get_class_timeline(UUID) TO authenticated;


-- 11c. remove_student_from_class
--      Old: teacher or admin
--      New: teacher, co-teacher, or admin
CREATE OR REPLACE FUNCTION remove_student_from_class(
  p_class_id  UUID,
  p_student_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_student_name TEXT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM classes WHERE id = p_class_id) THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  IF NOT is_class_teacher_or_coteacher(p_class_id) AND NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'You do not have permission to manage this class');
  END IF;

  SELECT name INTO v_student_name FROM users WHERE id = p_student_id;

  IF v_student_name IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Student not found');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM class_members WHERE class_id = p_class_id AND user_id = p_student_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Student is not in this class');
  END IF;

  DELETE FROM class_members WHERE class_id = p_class_id AND user_id = p_student_id;

  RETURN json_build_object(
    'success',      true,
    'message',      format('Removed %s from the class', v_student_name),
    'student_name', v_student_name
  );
END;
$$;

GRANT EXECUTE ON FUNCTION remove_student_from_class(UUID, UUID) TO authenticated;


-- 11d. update_student_name
--      Old: teacher or admin
--      New: teacher, co-teacher, or admin
CREATE OR REPLACE FUNCTION update_student_name(
  p_class_id   UUID,
  p_student_id UUID,
  p_new_name   TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_old_name TEXT;
BEGIN
  IF p_new_name IS NULL OR TRIM(p_new_name) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Name cannot be empty');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM classes WHERE id = p_class_id) THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  IF NOT is_class_teacher_or_coteacher(p_class_id) AND NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'You do not have permission to manage this class');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM class_members WHERE class_id = p_class_id AND user_id = p_student_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Student is not in this class');
  END IF;

  SELECT name INTO v_old_name FROM users WHERE id = p_student_id;

  UPDATE users SET name = TRIM(p_new_name) WHERE id = p_student_id;

  RETURN json_build_object(
    'success',  true,
    'message',  'Student name updated',
    'old_name', v_old_name,
    'new_name', TRIM(p_new_name)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION update_student_name(UUID, UUID, TEXT) TO authenticated;


-- 11e. transfer_student_between_classes
--      Old: must own both classes
--      New: must be teacher-or-coteacher of both classes
CREATE OR REPLACE FUNCTION transfer_student_between_classes(
  p_student_id    UUID,
  p_from_class_id UUID,
  p_to_class_id   UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_is_admin        BOOLEAN;
  v_from_class_name TEXT;
  v_to_class_name   TEXT;
  v_student_name    TEXT;
BEGIN
  v_is_admin := is_admin();

  SELECT name INTO v_from_class_name FROM classes WHERE id = p_from_class_id;
  IF v_from_class_name IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Source class not found');
  END IF;

  SELECT name INTO v_to_class_name FROM classes WHERE id = p_to_class_id;
  IF v_to_class_name IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Destination class not found');
  END IF;

  IF NOT v_is_admin THEN
    IF NOT is_class_teacher_or_coteacher(p_from_class_id) THEN
      RETURN json_build_object('success', false, 'message', 'You do not have permission to manage the source class');
    END IF;
    IF NOT is_class_teacher_or_coteacher(p_to_class_id) THEN
      RETURN json_build_object('success', false, 'message', 'You do not have permission to manage the destination class');
    END IF;
  END IF;

  IF p_from_class_id = p_to_class_id THEN
    RETURN json_build_object('success', false, 'message', 'Source and destination classes are the same');
  END IF;

  SELECT name INTO v_student_name FROM users WHERE id = p_student_id;
  IF v_student_name IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Student not found');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM class_members WHERE class_id = p_from_class_id AND user_id = p_student_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Student is not in the source class');
  END IF;

  DELETE FROM class_members WHERE class_id = p_from_class_id AND user_id = p_student_id;

  INSERT INTO class_members (class_id, user_id)
  VALUES (p_to_class_id, p_student_id)
  ON CONFLICT (class_id, user_id) DO NOTHING;

  RETURN json_build_object(
    'success', true,
    'message',  format('Transferred %s from %s to %s', v_student_name, v_from_class_name, v_to_class_name)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION transfer_student_between_classes(UUID, UUID, UUID) TO authenticated;


-- 11f. get_pending_enrollments
--      Old: class teacher or admin
--      New: class teacher, co-teacher, or admin
CREATE OR REPLACE FUNCTION get_pending_enrollments(p_class_id UUID)
RETURNS TABLE (
  id         UUID,
  email      TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  IF NOT is_class_teacher_or_coteacher(p_class_id) AND NOT is_admin() THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT pe.id, pe.email, pe.created_at
  FROM pending_enrollments pe
  WHERE pe.class_id = p_class_id
  ORDER BY pe.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_pending_enrollments(UUID) TO authenticated;


-- 11g. remove_pending_enrollment
--      Old: class teacher or admin
--      New: class teacher, co-teacher, or admin
CREATE OR REPLACE FUNCTION remove_pending_enrollment(p_enrollment_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_class_id UUID;
BEGIN
  SELECT class_id INTO v_class_id
  FROM pending_enrollments
  WHERE id = p_enrollment_id;

  IF v_class_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Pending enrollment not found');
  END IF;

  IF NOT is_class_teacher_or_coteacher(v_class_id) AND NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'You do not have permission to remove this enrollment');
  END IF;

  DELETE FROM pending_enrollments WHERE id = p_enrollment_id;

  RETURN json_build_object('success', true, 'message', 'Pending enrollment removed');
END;
$$;

GRANT EXECUTE ON FUNCTION remove_pending_enrollment(UUID) TO authenticated;


-- 11h. add_pending_enrollments
--      Old: class teacher or admin
--      New: class teacher, co-teacher, or admin
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
      INSERT INTO pending_enrollments (class_id, email)
      VALUES (p_class_id, v_email)
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


-- ============================================================
-- 12. Update get_teacher_classes() to include co-taught classes
--     and expose is_co_teacher in every result row.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_teacher_classes(
  p_teacher_id       UUID,
  p_include_archived BOOLEAN DEFAULT false,
  p_school_id        UUID    DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id     UUID;
  v_is_admin            BOOLEAN;
  v_result              JSON;
  v_shared_visibility   BOOLEAN := FALSE;
  v_effective_school_id UUID;
BEGIN
  v_current_user_id := auth.uid();
  v_is_admin := is_admin();

  IF v_current_user_id != p_teacher_id AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Permission denied: You can only view your own classes';
  END IF;

  IF NOT v_is_admin THEN
    IF p_school_id IS NOT NULL THEN
      v_effective_school_id := p_school_id;
    ELSE
      SELECT sm.school_id INTO v_effective_school_id
      FROM school_members sm
      WHERE sm.user_id = p_teacher_id
      ORDER BY sm.joined_at ASC
      LIMIT 1;
    END IF;

    IF v_effective_school_id IS NOT NULL THEN
      SELECT s.shared_class_visibility INTO v_shared_visibility
      FROM schools s
      WHERE s.id = v_effective_school_id;
    END IF;
  END IF;

  IF v_is_admin THEN
    SELECT json_agg(
      json_build_object(
        'id',            c.id,
        'name',          c.name,
        'year_level',    c.year_level,
        'class_code',    c.class_code,
        'teacher_id',    c.teacher_id,
        'teacher_name',  u.name,
        'school_name',   s.name,
        'school_id',     c.school_id,
        'created_at',    c.created_at,
        'archived',      c.archived,
        'is_co_teacher', false,
        'student_count', (SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = c.id),
        'pending_count', (SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = c.id)
      )
      ORDER BY u.name, c.created_at DESC
    )
    INTO v_result
    FROM classes c
    JOIN  users u ON u.id = c.teacher_id
    LEFT JOIN schools s ON s.id = c.school_id
    WHERE (p_include_archived = true OR c.archived = false)
      AND (p_school_id IS NULL OR c.school_id = p_school_id);

  ELSIF v_shared_visibility AND v_effective_school_id IS NOT NULL THEN
    SELECT json_agg(
      json_build_object(
        'id',            c.id,
        'name',          c.name,
        'year_level',    c.year_level,
        'class_code',    c.class_code,
        'teacher_id',    c.teacher_id,
        'teacher_name',  u.name,
        'school_name',   s.name,
        'school_id',     c.school_id,
        'created_at',    c.created_at,
        'archived',      c.archived,
        'is_co_teacher', (c.teacher_id != p_teacher_id),
        'student_count', (SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = c.id),
        'pending_count', (SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = c.id)
      )
      ORDER BY u.name, c.name
    )
    INTO v_result
    FROM classes c
    JOIN  users u ON u.id = c.teacher_id
    LEFT JOIN schools s ON s.id = c.school_id
    WHERE c.school_id = v_effective_school_id
      AND (p_include_archived = true OR c.archived = false);

  ELSE
    -- Standard: own classes UNION co-taught classes
    SELECT json_agg(
      json_build_object(
        'id',            combined.id,
        'name',          combined.name,
        'year_level',    combined.year_level,
        'class_code',    combined.class_code,
        'teacher_id',    combined.teacher_id,
        'teacher_name',  combined.teacher_name,
        'school_name',   combined.school_name,
        'school_id',     combined.school_id,
        'created_at',    combined.created_at,
        'archived',      combined.archived,
        'is_co_teacher', combined.is_co_teacher,
        'student_count', (SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = combined.id),
        'pending_count', (SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = combined.id)
      )
      ORDER BY combined.is_co_teacher ASC, combined.created_at DESC
    )
    INTO v_result
    FROM (
      -- Own classes
      SELECT c.id, c.name, c.year_level, c.class_code, c.teacher_id,
             u.name AS teacher_name, s.name AS school_name, c.school_id,
             c.created_at, c.archived, false AS is_co_teacher
      FROM classes c
      JOIN users u ON u.id = c.teacher_id
      LEFT JOIN schools s ON s.id = c.school_id
      WHERE c.teacher_id = p_teacher_id
        AND (p_include_archived = true OR c.archived = false)
        AND (p_school_id IS NULL OR c.school_id = p_school_id)

      UNION ALL

      -- Co-taught classes (explicitly added as co-teacher)
      SELECT c.id, c.name, c.year_level, c.class_code, c.teacher_id,
             u.name AS teacher_name, s.name AS school_name, c.school_id,
             c.created_at, c.archived, true AS is_co_teacher
      FROM classes c
      JOIN users u ON u.id = c.teacher_id
      LEFT JOIN schools s ON s.id = c.school_id
      JOIN class_co_teachers cct ON cct.class_id = c.id AND cct.teacher_id = p_teacher_id
      WHERE (p_include_archived = true OR c.archived = false)
        AND (p_school_id IS NULL OR c.school_id = p_school_id)
    ) combined;
  END IF;

  RETURN COALESCE(v_result, '[]'::json);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    RETURN '[]'::json;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_classes(UUID, BOOLEAN, UUID) TO authenticated;
