-- Teachers can invite colleagues directly from the School tab.
-- The invite pre-registers the email for teacher role AND records which
-- school to auto-join, so the invitee needs no join code.

-- Add school_id so an invite can auto-join the new teacher to a school
ALTER TABLE pre_registered_accounts
  ADD COLUMN school_id UUID REFERENCES schools(id) ON DELETE SET NULL;

-- Update check_pre_registration to return school_id so the client can
-- auto-join the school immediately after the user record is created.
CREATE OR REPLACE FUNCTION check_pre_registration(p_email TEXT)
RETURNS JSON AS $$
DECLARE
  v_record RECORD;
BEGIN
  SELECT role, name, school_id INTO v_record
  FROM pre_registered_accounts
  WHERE email = lower(trim(p_email));

  IF v_record IS NULL THEN
    RETURN json_build_object('found', false);
  END IF;

  -- Consume the pre-registration
  DELETE FROM pre_registered_accounts WHERE email = lower(trim(p_email));

  RETURN json_build_object(
    'found',     true,
    'role',      v_record.role,
    'name',      v_record.name,
    'school_id', v_record.school_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Adds the current authenticated user to a school by ID.
-- Used after pre-registration signup when a school_id was stored on the invite.
-- No join code required — the invite itself is the authorisation.
CREATE OR REPLACE FUNCTION auto_join_school_by_id(p_school_id UUID)
RETURNS JSON AS $$
DECLARE
  v_user_id   UUID;
  v_user_role TEXT;
  v_school_name TEXT;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role != 'teacher' THEN
    RETURN json_build_object('success', false, 'message', 'Only teachers can join schools');
  END IF;

  SELECT name INTO v_school_name FROM schools WHERE id = p_school_id;
  IF v_school_name IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'School not found');
  END IF;

  INSERT INTO school_members (school_id, user_id, school_role)
  VALUES (p_school_id, v_user_id, 'teacher')
  ON CONFLICT (school_id, user_id) DO NOTHING;

  RETURN json_build_object('success', true, 'school_name', v_school_name);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION auto_join_school_by_id(UUID) TO authenticated;
