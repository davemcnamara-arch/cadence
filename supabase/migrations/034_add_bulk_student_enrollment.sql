-- Migration: Add bulk student enrollment functionality
-- This allows teachers to pre-add students by email address
-- When students log in with matching emails, they are automatically enrolled

-- Create pending_enrollments table to store email -> class mappings
CREATE TABLE IF NOT EXISTS pending_enrollments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  added_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(class_id, email)
);

-- Create index for fast email lookups
CREATE INDEX idx_pending_enrollments_email ON pending_enrollments(LOWER(email));
CREATE INDEX idx_pending_enrollments_class ON pending_enrollments(class_id);

-- Enable RLS
ALTER TABLE pending_enrollments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for pending_enrollments
-- Teachers can view pending enrollments for their classes
CREATE POLICY "Teachers can view pending enrollments for their classes"
  ON pending_enrollments FOR SELECT
  USING (
    class_id IN (SELECT id FROM classes WHERE teacher_id = auth.uid())
  );

-- Teachers can add pending enrollments for their classes
CREATE POLICY "Teachers can add pending enrollments for their classes"
  ON pending_enrollments FOR INSERT
  WITH CHECK (
    class_id IN (SELECT id FROM classes WHERE teacher_id = auth.uid())
    AND added_by = auth.uid()
  );

-- Teachers can delete pending enrollments for their classes
CREATE POLICY "Teachers can delete pending enrollments for their classes"
  ON pending_enrollments FOR DELETE
  USING (
    class_id IN (SELECT id FROM classes WHERE teacher_id = auth.uid())
  );

-- Function to add multiple pending enrollments at once
CREATE OR REPLACE FUNCTION add_pending_enrollments(
  p_class_id UUID,
  p_emails TEXT[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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

  -- Verify the user owns this class
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE id = p_class_id;

  IF v_teacher_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Class not found'
    );
  END IF;

  IF v_teacher_id != v_user_id THEN
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

-- Function to process pending enrollments for a user (called on login)
CREATE OR REPLACE FUNCTION process_pending_enrollments(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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

-- Function to get pending enrollments for a class
CREATE OR REPLACE FUNCTION get_pending_enrollments(p_class_id UUID)
RETURNS TABLE (
  id UUID,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_id UUID;
BEGIN
  -- Verify caller owns this class
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE classes.id = p_class_id;

  IF v_teacher_id IS NULL OR v_teacher_id != auth.uid() THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT pe.id, pe.email, pe.created_at
  FROM pending_enrollments pe
  WHERE pe.class_id = p_class_id
  ORDER BY pe.created_at DESC;
END;
$$;

-- Function to remove a pending enrollment
CREATE OR REPLACE FUNCTION remove_pending_enrollment(p_enrollment_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_class_id UUID;
  v_teacher_id UUID;
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

  -- Verify caller owns this class
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE id = v_class_id;

  IF v_teacher_id != auth.uid() THEN
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

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION add_pending_enrollments(UUID, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION process_pending_enrollments(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_pending_enrollments(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_pending_enrollment(UUID) TO authenticated;
