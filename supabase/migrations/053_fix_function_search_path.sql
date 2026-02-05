-- Migration: Fix search_path security warnings for all public functions
-- This adds SET search_path = 'public' to all SECURITY DEFINER functions
-- to prevent search_path manipulation attacks

-- 1. update_updated_at (trigger function)
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql
SET search_path = 'public';

-- 2. generate_class_code
CREATE OR REPLACE FUNCTION generate_class_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INTEGER;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql
SET search_path = 'public';

-- 3. is_teacher (helper function)
CREATE OR REPLACE FUNCTION is_teacher()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role IN ('teacher', 'admin')
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = 'public';

-- 4. update_song_suggested_level
CREATE OR REPLACE FUNCTION update_song_suggested_level(
  p_song_id UUID,
  p_level INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  -- Only teachers and admins can update song levels
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role IN ('teacher', 'admin')
  ) THEN
    RAISE EXCEPTION 'Only teachers and admins can update song levels';
  END IF;

  -- Update the song's suggested level
  UPDATE songs
  SET suggested_level = p_level
  WHERE id = p_song_id;
END;
$$;

-- 5. approve_pending_link
CREATE OR REPLACE FUNCTION approve_pending_link(
  pending_link_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_song_id UUID;
  v_link_type TEXT;
  v_url TEXT;
BEGIN
  -- Get the pending link details
  SELECT song_id, link_type, url
  INTO v_song_id, v_link_type, v_url
  FROM pending_links
  WHERE id = pending_link_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending link not found or already processed';
  END IF;

  -- Update the song with the approved link
  IF v_link_type = 'youtube_url' THEN
    UPDATE songs SET youtube_url = v_url WHERE id = v_song_id;
  ELSIF v_link_type = 'chords_url' THEN
    UPDATE songs SET chords_url = v_url WHERE id = v_song_id;
  ELSIF v_link_type = 'tutorial_url' THEN
    UPDATE songs SET tutorial_url = v_url WHERE id = v_song_id;
  END IF;

  -- Mark the pending link as approved
  UPDATE pending_links
  SET status = 'approved',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = pending_link_id;
END;
$$;

-- 6. reject_pending_link
CREATE OR REPLACE FUNCTION reject_pending_link(
  pending_link_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  -- Mark the pending link as rejected
  UPDATE pending_links
  SET status = 'rejected',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = pending_link_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending link not found or already processed';
  END IF;
END;
$$;

-- 7. add_pending_enrollments
CREATE OR REPLACE FUNCTION add_pending_enrollments(
  p_class_id UUID,
  p_emails TEXT[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_teacher_id UUID;
  v_user_id UUID;
  v_email TEXT;
  v_added_count INTEGER := 0;
  v_skipped_count INTEGER := 0;
  v_already_enrolled_count INTEGER := 0;
BEGIN
  -- Get current user
  v_user_id := auth.uid();

  -- Verify the user owns this class or is an admin
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE id = p_class_id;

  IF v_teacher_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Class not found'
    );
  END IF;

  -- Check if user is admin
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_user_id AND role = 'admin') AND v_teacher_id != v_user_id THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You do not have permission to add students to this class'
    );
  END IF;

  -- Process each email
  FOREACH v_email IN ARRAY p_emails
  LOOP
    -- Normalize email
    v_email := LOWER(TRIM(v_email));

    -- Skip empty emails
    IF v_email = '' OR v_email IS NULL THEN
      CONTINUE;
    END IF;

    -- Check if user already exists and is enrolled
    IF EXISTS (
      SELECT 1 FROM class_members cm
      JOIN users u ON u.id = cm.user_id
      WHERE cm.class_id = p_class_id
      AND LOWER(u.email) = v_email
    ) THEN
      v_already_enrolled_count := v_already_enrolled_count + 1;
      CONTINUE;
    END IF;

    -- Check if already in pending enrollments
    IF EXISTS (
      SELECT 1 FROM pending_enrollments
      WHERE class_id = p_class_id
      AND LOWER(email) = v_email
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    -- Add to pending enrollments
    INSERT INTO pending_enrollments (class_id, email, added_by)
    VALUES (p_class_id, v_email, v_user_id);

    v_added_count := v_added_count + 1;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'added', v_added_count,
    'skipped', v_skipped_count,
    'already_enrolled', v_already_enrolled_count,
    'message', format('Added %s email(s). %s already pending. %s already enrolled.',
      v_added_count, v_skipped_count, v_already_enrolled_count)
  );
END;
$$;

-- 8. process_pending_enrollments
CREATE OR REPLACE FUNCTION process_pending_enrollments(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_user_email TEXT;
  v_pending RECORD;
  v_enrolled_count INTEGER := 0;
  v_class_names TEXT[] := ARRAY[]::TEXT[];
BEGIN
  -- Get user's email
  SELECT email INTO v_user_email
  FROM users
  WHERE id = p_user_id;

  IF v_user_email IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'User not found',
      'enrolled_count', 0
    );
  END IF;

  -- Find and process all pending enrollments for this email
  FOR v_pending IN
    SELECT pe.id, pe.class_id, c.name as class_name
    FROM pending_enrollments pe
    JOIN classes c ON c.id = pe.class_id
    WHERE LOWER(pe.email) = LOWER(v_user_email)
    AND c.archived = false
  LOOP
    -- Check if already a member (shouldn't happen, but be safe)
    IF NOT EXISTS (
      SELECT 1 FROM class_members
      WHERE class_id = v_pending.class_id
      AND user_id = p_user_id
    ) THEN
      -- Enroll the student
      INSERT INTO class_members (class_id, user_id, joined_at)
      VALUES (v_pending.class_id, p_user_id, NOW());

      v_enrolled_count := v_enrolled_count + 1;
      v_class_names := array_append(v_class_names, v_pending.class_name);
    END IF;

    -- Remove the pending enrollment
    DELETE FROM pending_enrollments WHERE id = v_pending.id;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'enrolled_count', v_enrolled_count,
    'class_names', v_class_names,
    'message', CASE
      WHEN v_enrolled_count > 0 THEN format('Automatically enrolled in %s class(es)', v_enrolled_count)
      ELSE 'No pending enrollments found'
    END
  );
END;
$$;

-- 9. get_pending_enrollments
CREATE OR REPLACE FUNCTION get_pending_enrollments(p_class_id UUID)
RETURNS TABLE (
  id UUID,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_teacher_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  -- Check if user is admin
  SELECT role = 'admin' INTO v_is_admin
  FROM users WHERE users.id = auth.uid();

  -- Verify caller owns this class or is admin
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE classes.id = p_class_id;

  IF v_teacher_id IS NULL OR (v_teacher_id != auth.uid() AND NOT COALESCE(v_is_admin, false)) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT pe.id, pe.email, pe.created_at
  FROM pending_enrollments pe
  WHERE pe.class_id = p_class_id
  ORDER BY pe.created_at DESC;
END;
$$;

-- 10. remove_pending_enrollment
CREATE OR REPLACE FUNCTION remove_pending_enrollment(p_enrollment_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_class_id UUID;
  v_teacher_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  -- Get the class_id for this enrollment
  SELECT class_id INTO v_class_id
  FROM pending_enrollments
  WHERE id = p_enrollment_id;

  IF v_class_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Pending enrollment not found'
    );
  END IF;

  -- Check if user is admin
  SELECT role = 'admin' INTO v_is_admin
  FROM users WHERE users.id = auth.uid();

  -- Verify caller owns this class or is admin
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE id = v_class_id;

  IF v_teacher_id != auth.uid() AND NOT COALESCE(v_is_admin, false) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You do not have permission to remove this enrollment'
    );
  END IF;

  -- Delete the pending enrollment
  DELETE FROM pending_enrollments WHERE id = p_enrollment_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Pending enrollment removed'
  );
END;
$$;

-- 11. remove_student_from_class
CREATE OR REPLACE FUNCTION remove_student_from_class(
  p_class_id UUID,
  p_student_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
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

-- 12. update_student_name
CREATE OR REPLACE FUNCTION update_student_name(
  p_class_id UUID,
  p_student_id UUID,
  p_new_name TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
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

-- 13. approve_student_resource
CREATE OR REPLACE FUNCTION approve_student_resource(
  p_resource_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE student_resources
  SET status = 'approved',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = p_resource_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource not found or already processed';
  END IF;
END;
$$;

-- 14. reject_student_resource
CREATE OR REPLACE FUNCTION reject_student_resource(
  p_resource_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE student_resources
  SET status = 'rejected',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = p_resource_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource not found or already processed';
  END IF;
END;
$$;

-- 15. approve_song_tutorial
CREATE OR REPLACE FUNCTION approve_song_tutorial(
  p_tutorial_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE song_tutorials
  SET status = 'approved',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = p_tutorial_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tutorial not found or already processed';
  END IF;
END;
$$;

-- 16. reject_song_tutorial
CREATE OR REPLACE FUNCTION reject_song_tutorial(
  p_tutorial_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  UPDATE song_tutorials
  SET status = 'rejected',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = p_tutorial_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tutorial not found or already processed';
  END IF;
END;
$$;

-- 17. get_song_resources
CREATE OR REPLACE FUNCTION get_song_resources(
  p_song_id UUID
)
RETURNS TABLE (
  resource_id UUID,
  resource_title TEXT,
  resource_description TEXT,
  resource_file_url TEXT,
  resource_file_type TEXT,
  resource_status TEXT,
  contributor_name TEXT,
  resource_created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_is_teacher BOOLEAN;
BEGIN
  -- Check if current user is a teacher
  SELECT role IN ('teacher', 'admin') INTO v_is_teacher
  FROM users WHERE users.id = auth.uid();

  RETURN QUERY
  SELECT
    sr.id AS resource_id,
    sr.title AS resource_title,
    sr.description AS resource_description,
    sr.file_url AS resource_file_url,
    sr.file_type AS resource_file_type,
    sr.status AS resource_status,
    COALESCE(u.name, 'Student')::TEXT AS contributor_name,
    sr.created_at AS resource_created_at
  FROM student_resources sr
  LEFT JOIN users u ON sr.user_id = u.id
  WHERE sr.song_id = p_song_id
    AND (sr.status = 'approved' OR v_is_teacher OR sr.user_id = auth.uid())
  ORDER BY sr.created_at DESC;
END;
$$;

-- 18. get_song_tutorials
CREATE OR REPLACE FUNCTION get_song_tutorials(
  p_song_id UUID
)
RETURNS TABLE (
  tutorial_id UUID,
  tutorial_url TEXT,
  tutorial_title TEXT,
  tutorial_status TEXT,
  contributor_name TEXT,
  tutorial_created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_is_teacher BOOLEAN;
BEGIN
  -- Check if current user is a teacher
  SELECT role IN ('teacher', 'admin') INTO v_is_teacher
  FROM users WHERE users.id = auth.uid();

  RETURN QUERY
  SELECT
    st.id AS tutorial_id,
    st.url AS tutorial_url,
    st.title AS tutorial_title,
    st.status AS tutorial_status,
    COALESCE(u.name, 'Teacher')::TEXT AS contributor_name,
    st.created_at AS tutorial_created_at
  FROM song_tutorials st
  LEFT JOIN users u ON st.submitted_by_user_id = u.id
  WHERE st.song_id = p_song_id
    AND (st.status = 'approved' OR v_is_teacher OR st.submitted_by_user_id = auth.uid())
  ORDER BY st.created_at ASC;
END;
$$;

-- 19. add_song_tutorial
CREATE OR REPLACE FUNCTION add_song_tutorial(
  p_song_id UUID,
  p_url TEXT,
  p_title TEXT DEFAULT NULL,
  p_status TEXT DEFAULT 'pending'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  INSERT INTO song_tutorials (song_id, url, title, submitted_by_user_id, status)
  VALUES (p_song_id, p_url, p_title, auth.uid(), p_status);
END;
$$;

-- 20. check_pre_registration
CREATE OR REPLACE FUNCTION check_pre_registration(p_email TEXT)
RETURNS JSON AS $$
DECLARE
  v_record RECORD;
  v_transferred_count INTEGER := 0;
BEGIN
  SELECT role, name INTO v_record
  FROM pre_registered_accounts
  WHERE email = lower(trim(p_email));

  IF v_record IS NULL THEN
    RETURN json_build_object('found', false, 'transferred_classes', 0);
  END IF;

  -- Delete the pre-registration entry (it's been used)
  DELETE FROM pre_registered_accounts WHERE email = lower(trim(p_email));

  RETURN json_build_object(
    'found', true,
    'role', v_record.role,
    'name', v_record.name,
    'transferred_classes', v_transferred_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

-- 21. delete_user_account
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
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

-- 22. get_manageable_users
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
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

-- 23. transfer_pending_classes
CREATE OR REPLACE FUNCTION transfer_pending_classes(p_email TEXT, p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_transferred_count INTEGER;
BEGIN
  -- Transfer all classes with matching pending_teacher_email to the new user
  UPDATE classes
  SET
    teacher_id = p_user_id,
    pending_teacher_email = NULL
  WHERE lower(pending_teacher_email) = lower(trim(p_email));

  GET DIAGNOSTICS v_transferred_count = ROW_COUNT;

  RETURN v_transferred_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

-- 24. complete_pending_teacher_setup
CREATE OR REPLACE FUNCTION complete_pending_teacher_setup(p_email TEXT)
RETURNS JSON AS $$
DECLARE
  v_user_id UUID;
  v_transferred_count INTEGER := 0;
BEGIN
  -- Get the user ID for this email
  SELECT id INTO v_user_id
  FROM users
  WHERE lower(email) = lower(trim(p_email));

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  -- Transfer all classes with matching pending_teacher_email to this user
  UPDATE classes
  SET
    teacher_id = v_user_id,
    pending_teacher_email = NULL
  WHERE lower(pending_teacher_email) = lower(trim(p_email));

  GET DIAGNOSTICS v_transferred_count = ROW_COUNT;

  RETURN json_build_object(
    'success', true,
    'transferred_classes', v_transferred_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

-- 25. promote_to_teacher
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
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

-- 26. change_user_role
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
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';
