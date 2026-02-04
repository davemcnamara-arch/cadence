-- Migration: Add function to change user roles (admin only)
-- This allows admins to change any user's role

-- Function to change a user's role
CREATE OR REPLACE FUNCTION change_user_role(p_user_id UUID, p_new_role TEXT)
RETURNS JSON AS $$
DECLARE
  v_caller_role TEXT;
  v_target_role TEXT;
  v_target_name TEXT;
  v_target_email TEXT;
BEGIN
  -- Validate new role
  IF p_new_role NOT IN ('student', 'teacher', 'admin') THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Invalid role. Must be student, teacher, or admin'
    );
  END IF;

  -- Get caller's role
  SELECT role INTO v_caller_role FROM users WHERE id = auth.uid();

  -- Only admins can change roles
  IF v_caller_role != 'admin' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Only admins can change user roles'
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

  -- Cannot change own role
  IF p_user_id = auth.uid() THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Cannot change your own role'
    );
  END IF;

  -- Cannot demote other admins
  IF v_target_role = 'admin' THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Cannot change the role of another admin'
    );
  END IF;

  -- No change needed
  IF v_target_role = p_new_role THEN
    RETURN json_build_object(
      'success', true,
      'message', 'User already has this role',
      'name', v_target_name,
      'role', p_new_role
    );
  END IF;

  -- Update the user's role
  UPDATE users
  SET role = p_new_role, updated_at = NOW()
  WHERE id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'message', 'User role updated successfully',
    'name', v_target_name,
    'email', v_target_email,
    'old_role', v_target_role,
    'new_role', p_new_role
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION change_user_role(UUID, TEXT) TO authenticated;
