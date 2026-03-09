-- ============================================================
-- MIGRATION 082: Admin remove of teachers / students from schools
-- ============================================================

-- ============================================================
-- FUNCTION: remove_teacher_from_school
-- Admin removes a teacher (and their school_role) from a school.
-- Does NOT affect the teacher's classes or students.
-- ============================================================
CREATE OR REPLACE FUNCTION remove_teacher_from_school(p_school_id UUID, p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id   UUID;
  v_caller_role TEXT;
  v_target_role TEXT;
BEGIN
  v_caller_id := auth.uid();
  SELECT role INTO v_caller_role FROM users WHERE id = v_caller_id;

  IF v_caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM schools WHERE id = p_school_id) THEN
    RETURN json_build_object('success', false, 'message', 'School not found');
  END IF;

  SELECT school_role INTO v_target_role
  FROM school_members WHERE school_id = p_school_id AND user_id = p_user_id;

  IF v_target_role IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Teacher is not in this school');
  END IF;

  DELETE FROM school_members WHERE school_id = p_school_id AND user_id = p_user_id;

  RETURN json_build_object('success', true, 'message', 'Teacher removed from school');
END;
$$;

-- ============================================================
-- FUNCTION: remove_student_from_school
-- Admin removes a student from a school's school_students table.
-- ============================================================
CREATE OR REPLACE FUNCTION remove_student_from_school(p_school_id UUID, p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id   UUID;
  v_caller_role TEXT;
BEGIN
  v_caller_id := auth.uid();
  SELECT role INTO v_caller_role FROM users WHERE id = v_caller_id;

  IF v_caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM schools WHERE id = p_school_id) THEN
    RETURN json_build_object('success', false, 'message', 'School not found');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM school_students WHERE school_id = p_school_id AND user_id = p_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Student is not in this school');
  END IF;

  DELETE FROM school_students WHERE school_id = p_school_id AND user_id = p_user_id;

  RETURN json_build_object('success', true, 'message', 'Student removed from school');
END;
$$;
