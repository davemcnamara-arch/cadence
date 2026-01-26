-- Account Management: Pre-registration, user deletion, and manageable user listing

-- Pre-registered accounts table (for creating teacher accounts before they sign in)
CREATE TABLE pre_registered_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL DEFAULT 'teacher' CHECK (role IN ('teacher', 'admin')),
  name TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE pre_registered_accounts ENABLE ROW LEVEL SECURITY;

-- RLS: Teachers and admins can view pre-registered accounts
CREATE POLICY "Teachers and admins can view pre-registered accounts"
ON pre_registered_accounts FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);

-- RLS: Teachers and admins can insert pre-registered accounts
CREATE POLICY "Teachers and admins can insert pre-registered accounts"
ON pre_registered_accounts FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);

-- RLS: Teachers and admins can delete pre-registered accounts
CREATE POLICY "Teachers and admins can delete pre-registered accounts"
ON pre_registered_accounts FOR DELETE USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);

-- Function to check pre-registration on sign-in (called from auth.js)
CREATE OR REPLACE FUNCTION check_pre_registration(p_email TEXT)
RETURNS JSON AS $$
DECLARE
  v_record RECORD;
BEGIN
  SELECT role, name INTO v_record
  FROM pre_registered_accounts
  WHERE email = lower(trim(p_email));

  IF v_record IS NULL THEN
    RETURN json_build_object('found', false);
  END IF;

  -- Delete the pre-registration entry (it's been used)
  DELETE FROM pre_registered_accounts WHERE email = lower(trim(p_email));

  RETURN json_build_object(
    'found', true,
    'role', v_record.role,
    'name', v_record.name
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete a user account (with authorization checks)
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

  IF v_caller_role IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Unauthorized');
  END IF;

  -- Get target's role and name
  SELECT role, name INTO v_target_role, v_target_name FROM users WHERE id = p_user_id;

  IF v_target_role IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  -- Authorization checks
  IF v_target_role = 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Cannot delete admin accounts');
  END IF;

  IF v_target_role = 'teacher' AND v_caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Only admins can delete teacher accounts');
  END IF;

  IF v_target_role = 'student' AND v_caller_role NOT IN ('teacher', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Only teachers and admins can delete student accounts');
  END IF;

  -- Delete the user (cascades to student_progress, song_ratings, student_songs, class_members, classes)
  DELETE FROM users WHERE id = p_user_id;

  RETURN json_build_object('success', true, 'message', 'Account deleted successfully', 'name', v_target_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get users that the current user can manage
CREATE OR REPLACE FUNCTION get_manageable_users()
RETURNS TABLE(id UUID, email TEXT, name TEXT, role TEXT, created_at TIMESTAMPTZ) AS $$
DECLARE
  v_caller_role TEXT;
BEGIN
  SELECT u.role INTO v_caller_role FROM users u WHERE u.id = auth.uid();

  IF v_caller_role = 'admin' THEN
    -- Admins can see all users except themselves
    RETURN QUERY
    SELECT u.id, u.email, u.name, u.role, u.created_at
    FROM users u
    WHERE u.id != auth.uid()
    ORDER BY u.role, u.created_at DESC;
  ELSIF v_caller_role = 'teacher' THEN
    -- Teachers can see students in their classes
    RETURN QUERY
    SELECT DISTINCT u.id, u.email, u.name, u.role, u.created_at
    FROM users u
    JOIN class_members cm ON cm.user_id = u.id
    JOIN classes c ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid() AND u.role = 'student'
    ORDER BY u.created_at DESC;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
