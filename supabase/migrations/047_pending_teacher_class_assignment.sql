-- Allow classes to be assigned to pending teachers
-- When a pending teacher signs up, their classes are transferred to them

-- Add pending_teacher_email column to classes
ALTER TABLE classes ADD COLUMN IF NOT EXISTS pending_teacher_email TEXT;

-- Create index for faster lookups when teacher signs up
CREATE INDEX IF NOT EXISTS idx_classes_pending_teacher_email ON classes(pending_teacher_email) WHERE pending_teacher_email IS NOT NULL;

-- Function to transfer classes to a newly registered teacher
-- Called when a pending teacher signs up and their email matches pending_teacher_email
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update check_pre_registration to also transfer classes
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Separate function to complete class transfer after user record is created
-- This should be called from the client after the user record exists
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
$$ LANGUAGE plpgsql SECURITY DEFINER;
