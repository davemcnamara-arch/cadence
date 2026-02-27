-- Functions to add/remove instruments on behalf of students
-- Bypasses RLS and validates access internally, consistent with other
-- teacher-on-behalf-of-student functions (add_student_song, grade_song, etc.)

-- ============================================================================
-- 1. add_instrument_for_student
-- ============================================================================
CREATE OR REPLACE FUNCTION add_instrument_for_student(
  p_student_id   UUID,
  p_instrument_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_caller_id UUID;
  v_has_access BOOLEAN;
  v_result     JSON;
BEGIN
  v_caller_id := auth.uid();

  -- Caller must be the student themselves OR a teacher with the student in their class
  SELECT (
    v_caller_id = p_student_id
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_caller_id
        AND cm.user_id = p_student_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- Prevent duplicate entries (surface a clear error rather than a constraint crash)
  IF EXISTS (
    SELECT 1 FROM student_progress
    WHERE user_id = p_student_id AND instrument_id = p_instrument_id
  ) THEN
    RAISE EXCEPTION 'Student already has this instrument';
  END IF;

  INSERT INTO student_progress (user_id, instrument_id, current_level)
  VALUES (p_student_id, p_instrument_id, 1)
  RETURNING json_build_object(
    'id',            id,
    'user_id',       user_id,
    'instrument_id', instrument_id,
    'current_level', current_level,
    'current_branch', current_branch,
    'date_started',  date_started,
    'last_updated',  last_updated
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION add_instrument_for_student(UUID, UUID) TO authenticated;

-- ============================================================================
-- 2. remove_instrument_for_student
-- ============================================================================
CREATE OR REPLACE FUNCTION remove_instrument_for_student(
  p_student_id    UUID,
  p_instrument_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_caller_id UUID;
  v_has_access BOOLEAN;
BEGIN
  v_caller_id := auth.uid();

  -- Caller must be the student themselves OR a teacher with the student in their class
  SELECT (
    v_caller_id = p_student_id
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_caller_id
        AND cm.user_id = p_student_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- Delete all student songs for this instrument first (preserves referential integrity)
  DELETE FROM student_songs
  WHERE user_id = p_student_id AND instrument_id = p_instrument_id;

  -- Delete the progress record
  DELETE FROM student_progress
  WHERE user_id = p_student_id AND instrument_id = p_instrument_id;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION remove_instrument_for_student(UUID, UUID) TO authenticated;
