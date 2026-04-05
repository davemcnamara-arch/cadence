-- Restrict delete_user_account to admins only.
-- Teachers can remove students from classes (class_members) but should not
-- be able to permanently delete accounts and all associated data.

CREATE OR REPLACE FUNCTION delete_user_account(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_caller_role TEXT;
  v_target_role TEXT;
  v_target_name TEXT;
BEGIN
  -- Cannot delete yourself
  IF p_user_id = auth.uid() THEN
    RETURN json_build_object('success', false, 'message', 'Cannot delete your own account');
  END IF;

  -- Get caller's role
  SELECT role INTO v_caller_role FROM users WHERE id = auth.uid();

  -- Only admins can delete accounts
  IF v_caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Only admins can delete accounts');
  END IF;

  -- Get target's role and name
  SELECT role, name INTO v_target_role, v_target_name FROM users WHERE id = p_user_id;

  IF v_target_role IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  IF v_target_role = 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Cannot delete admin accounts');
  END IF;

  -- Delete the user (cascades to student_progress, song_ratings, student_songs, class_members, classes)
  DELETE FROM users WHERE id = p_user_id;

  RETURN json_build_object('success', true, 'message', 'Account deleted successfully', 'name', v_target_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
