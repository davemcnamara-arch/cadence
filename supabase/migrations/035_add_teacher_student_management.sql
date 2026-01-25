-- Migration: Add teacher student management functions
-- Allows teachers to remove students from classes and edit student names

-- Function to remove a student from a class
CREATE OR REPLACE FUNCTION remove_student_from_class(
  p_class_id UUID,
  p_student_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_id UUID;
  v_student_name TEXT;
BEGIN
  -- Verify the caller owns this class
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE id = p_class_id;

  IF v_teacher_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Class not found'
    );
  END IF;

  IF v_teacher_id != auth.uid() THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You do not have permission to manage this class'
    );
  END IF;

  -- Get student name for confirmation message
  SELECT name INTO v_student_name
  FROM users
  WHERE id = p_student_id;

  IF v_student_name IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Student not found'
    );
  END IF;

  -- Check if student is in the class
  IF NOT EXISTS (
    SELECT 1 FROM class_members
    WHERE class_id = p_class_id AND user_id = p_student_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Student is not in this class'
    );
  END IF;

  -- Remove the student from the class
  DELETE FROM class_members
  WHERE class_id = p_class_id AND user_id = p_student_id;

  RETURN json_build_object(
    'success', true,
    'message', format('Removed %s from the class', v_student_name),
    'student_name', v_student_name
  );
END;
$$;

-- Function to update a student's name (teacher can edit students in their classes)
CREATE OR REPLACE FUNCTION update_student_name(
  p_class_id UUID,
  p_student_id UUID,
  p_new_name TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_id UUID;
  v_old_name TEXT;
BEGIN
  -- Validate input
  IF p_new_name IS NULL OR TRIM(p_new_name) = '' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Name cannot be empty'
    );
  END IF;

  -- Verify the caller owns this class
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE id = p_class_id;

  IF v_teacher_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Class not found'
    );
  END IF;

  IF v_teacher_id != auth.uid() THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You do not have permission to manage this class'
    );
  END IF;

  -- Check if student is in the class
  IF NOT EXISTS (
    SELECT 1 FROM class_members
    WHERE class_id = p_class_id AND user_id = p_student_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Student is not in this class'
    );
  END IF;

  -- Get old name
  SELECT name INTO v_old_name
  FROM users
  WHERE id = p_student_id;

  -- Update the student's name
  UPDATE users
  SET name = TRIM(p_new_name)
  WHERE id = p_student_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Student name updated',
    'old_name', v_old_name,
    'new_name', TRIM(p_new_name)
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION remove_student_from_class(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_student_name(UUID, UUID, TEXT) TO authenticated;
