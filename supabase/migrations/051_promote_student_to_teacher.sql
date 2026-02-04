-- Migration: Add function to promote students to teachers
-- This allows admins to upgrade student accounts to teacher accounts

-- Function to promote a student to teacher role
CREATE OR REPLACE FUNCTION promote_to_teacher(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_caller_role TEXT;
  v_target_role TEXT;
  v_target_name TEXT;
  v_target_email TEXT;
BEGIN
  -- Get caller's role
  SELECT role INTO v_caller_role FROM users WHERE id = auth.uid();

  -- Only admins can promote users
  IF v_caller_role != 'admin' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Only admins can promote users to teacher'
    );
  END IF;

  -- Get target user info
  SELECT role, name, email INTO v_target_role, v_target_name, v_target_email
  FROM users WHERE id = p_user_id;

  -- Check if user exists
  IF v_target_role IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'User not found'
    );
  END IF;

  -- Can only promote students
  IF v_target_role != 'student' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Can only promote student accounts to teacher'
    );
  END IF;

  -- Promote the user
  UPDATE users
  SET role = 'teacher', updated_at = NOW()
  WHERE id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'message', 'User promoted to teacher successfully',
    'name', v_target_name,
    'email', v_target_email
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION promote_to_teacher(UUID) TO authenticated;
