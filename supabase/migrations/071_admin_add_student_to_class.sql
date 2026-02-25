-- Allow admins to add any student directly to any class by user ID.
-- This is useful when a student account exists but they are not currently
-- enrolled in any (or a specific) class.

CREATE OR REPLACE FUNCTION admin_add_student_to_class(
  p_student_id UUID,
  p_class_id   UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_student_name TEXT;
  v_class_name   TEXT;
BEGIN
  -- Admin only
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
  END IF;

  -- Verify student exists
  SELECT name INTO v_student_name FROM users WHERE id = p_student_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Student not found');
  END IF;

  -- Verify class exists
  SELECT name INTO v_class_name FROM classes WHERE id = p_class_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  -- Check not already enrolled
  IF EXISTS (
    SELECT 1 FROM class_members
    WHERE class_id = p_class_id AND user_id = p_student_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', v_student_name || ' is already in ' || v_class_name
    );
  END IF;

  -- Enrol the student
  INSERT INTO class_members (class_id, user_id)
  VALUES (p_class_id, p_student_id);

  RETURN json_build_object(
    'success', true,
    'message', v_student_name || ' added to ' || v_class_name
  );
END;
$$;
