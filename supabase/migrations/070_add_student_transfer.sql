-- Add student transfer functionality
-- 1. Fix add_pending_enrollments to directly enroll existing users (no longer leaves them "pending")
-- 2. Add transfer_student_between_classes function for teachers and admins

-- ============================================================================
-- 1. Update add_pending_enrollments to directly enroll users who already exist
-- ============================================================================
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
  v_existing_user_id UUID;
  v_email TEXT;
  v_added_count INTEGER := 0;
  v_direct_enrolled_count INTEGER := 0;
  v_skipped_count INTEGER := 0;
  v_already_enrolled_count INTEGER := 0;
BEGIN
  -- Get current user
  v_user_id := auth.uid();

  -- Verify the class exists
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE id = p_class_id;

  IF v_teacher_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Class not found'
    );
  END IF;

  -- Check if user is admin or the class teacher
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

    -- Check if user already exists and is enrolled in this class
    IF EXISTS (
      SELECT 1 FROM class_members cm
      JOIN users u ON u.id = cm.user_id
      WHERE cm.class_id = p_class_id
      AND LOWER(u.email) = v_email
    ) THEN
      v_already_enrolled_count := v_already_enrolled_count + 1;
      CONTINUE;
    END IF;

    -- Check if user already has an account
    SELECT id INTO v_existing_user_id
    FROM users
    WHERE LOWER(email) = v_email
    LIMIT 1;

    IF v_existing_user_id IS NOT NULL THEN
      -- User already exists: enroll them directly into class_members
      -- Remove any stale pending enrollment for this email/class first
      DELETE FROM pending_enrollments
      WHERE class_id = p_class_id AND LOWER(email) = v_email;

      INSERT INTO class_members (class_id, user_id, joined_at)
      VALUES (p_class_id, v_existing_user_id, NOW())
      ON CONFLICT (class_id, user_id) DO NOTHING;

      v_direct_enrolled_count := v_direct_enrolled_count + 1;
      CONTINUE;
    END IF;

    -- User does not yet exist: add to pending enrollments
    IF EXISTS (
      SELECT 1 FROM pending_enrollments
      WHERE class_id = p_class_id
      AND LOWER(email) = v_email
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    INSERT INTO pending_enrollments (class_id, email, added_by)
    VALUES (p_class_id, v_email, v_user_id);

    v_added_count := v_added_count + 1;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'added', v_added_count,
    'direct_enrolled', v_direct_enrolled_count,
    'skipped', v_skipped_count,
    'already_enrolled', v_already_enrolled_count,
    'message', CASE
      WHEN v_direct_enrolled_count > 0 AND v_added_count > 0 THEN
        format('Enrolled %s student(s) directly. Added %s email(s) as pending.',
          v_direct_enrolled_count, v_added_count)
      WHEN v_direct_enrolled_count > 0 THEN
        format('Enrolled %s existing student(s) directly into the class.',
          v_direct_enrolled_count)
      WHEN v_added_count > 0 THEN
        format('Added %s email(s). Student(s) will be auto-enrolled when they log in.',
          v_added_count)
      WHEN v_already_enrolled_count > 0 THEN
        'All students are already enrolled in this class.'
      ELSE
        'No new students to add.'
    END
  );
END;
$$;

-- ============================================================================
-- 2. Add transfer_student_between_classes function
--    Teachers: can transfer between their own classes
--    Admins: can transfer between any classes
-- ============================================================================
CREATE OR REPLACE FUNCTION transfer_student_between_classes(
  p_student_id UUID,
  p_from_class_id UUID,
  p_to_class_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_caller_id UUID;
  v_from_teacher_id UUID;
  v_to_teacher_id UUID;
  v_student_name TEXT;
  v_from_class_name TEXT;
  v_to_class_name TEXT;
  v_is_admin BOOLEAN;
BEGIN
  v_caller_id := auth.uid();

  -- Determine if caller is admin
  SELECT (role = 'admin') INTO v_is_admin
  FROM users
  WHERE id = v_caller_id;

  -- Look up from-class
  SELECT teacher_id, name INTO v_from_teacher_id, v_from_class_name
  FROM classes
  WHERE id = p_from_class_id;

  IF v_from_teacher_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Source class not found');
  END IF;

  -- Look up to-class
  SELECT teacher_id, name INTO v_to_teacher_id, v_to_class_name
  FROM classes
  WHERE id = p_to_class_id;

  IF v_to_teacher_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Destination class not found');
  END IF;

  -- Authorization checks
  IF NOT v_is_admin THEN
    -- Teacher must own both classes
    IF v_from_teacher_id != v_caller_id THEN
      RETURN json_build_object('success', false, 'message', 'You do not have permission to manage the source class');
    END IF;
    IF v_to_teacher_id != v_caller_id THEN
      RETURN json_build_object('success', false, 'message', 'You do not have permission to manage the destination class');
    END IF;
  END IF;

  -- Cannot transfer to the same class
  IF p_from_class_id = p_to_class_id THEN
    RETURN json_build_object('success', false, 'message', 'Source and destination classes are the same');
  END IF;

  -- Look up student
  SELECT name INTO v_student_name
  FROM users
  WHERE id = p_student_id;

  IF v_student_name IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Student not found');
  END IF;

  -- Confirm student is actually in the source class
  IF NOT EXISTS (
    SELECT 1 FROM class_members
    WHERE class_id = p_from_class_id AND user_id = p_student_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Student is not in the source class');
  END IF;

  -- Remove from source class
  DELETE FROM class_members
  WHERE class_id = p_from_class_id AND user_id = p_student_id;

  -- Add to destination class (no-op if already a member)
  INSERT INTO class_members (class_id, user_id, joined_at)
  VALUES (p_to_class_id, p_student_id, NOW())
  ON CONFLICT (class_id, user_id) DO NOTHING;

  RETURN json_build_object(
    'success', true,
    'message', format('Transferred %s from %s to %s', v_student_name, v_from_class_name, v_to_class_name),
    'student_name', v_student_name,
    'from_class_name', v_from_class_name,
    'to_class_name', v_to_class_name
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION add_pending_enrollments(UUID, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION transfer_student_between_classes(UUID, UUID, UUID) TO authenticated;
