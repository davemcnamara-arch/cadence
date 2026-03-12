-- Database function to allow students to join classes by code
-- This bypasses RLS policies to search for classes while still enforcing proper access control
-- Updated: enforces the 15-student limit for Individual-plan teachers

CREATE OR REPLACE FUNCTION join_class_by_code(
  p_user_id UUID,
  p_class_code TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- Run with function creator's permissions to bypass RLS
AS $$
DECLARE
  v_class_id       UUID;
  v_class_name     TEXT;
  v_teacher_id     UUID;
  v_already_member BOOLEAN;
BEGIN
  -- Find the class by code (case-insensitive, non-archived only)
  SELECT id, name, teacher_id INTO v_class_id, v_class_name, v_teacher_id
  FROM classes
  WHERE UPPER(class_code) = UPPER(p_class_code)
    AND archived = false
  LIMIT 1;

  -- If class not found
  IF v_class_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Class not found. Please check the code.'
    );
  END IF;

  -- Check if already a member
  SELECT EXISTS(
    SELECT 1 FROM class_members
    WHERE class_id = v_class_id AND user_id = p_user_id
  ) INTO v_already_member;

  IF v_already_member THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You are already in this class',
      'class_name', v_class_name
    );
  END IF;

  -- Enforce tier-based student limit for Individual-plan teachers
  IF v_teacher_id IS NOT NULL AND NOT check_can_add_student(v_teacher_id) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'This class cannot accept new students. The teacher has reached the 15-student limit for an Individual subscription. Ask your teacher to upgrade to a School subscription for unlimited students.'
    );
  END IF;

  -- Join the class
  INSERT INTO class_members (class_id, user_id, joined_at)
  VALUES (v_class_id, p_user_id, NOW());

  -- Return success
  RETURN json_build_object(
    'success', true,
    'message', 'Successfully joined class',
    'class_name', v_class_name,
    'class_id', v_class_id
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', 'An error occurred while joining the class'
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION join_class_by_code(UUID, TEXT) TO authenticated;
