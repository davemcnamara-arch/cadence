-- ============================================================
-- MIGRATION 106: Allow teachers with an active school plan to
--                create a school
--
-- Migration 076 restricted create_school() to the 'admin' role,
-- which predated the subscription system. Teachers who purchase
-- the school plan must be able to create (and name) their own
-- school during onboarding.
--
-- New rule:
--   - system admins can always create a school
--   - teachers can create a school if they have an active/trialing
--     school-plan subscription
-- ============================================================

CREATE OR REPLACE FUNCTION create_school(p_name TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID;
  v_user_role TEXT;
  v_school_id UUID;
  v_join_code TEXT;
  v_existing_school_id UUID;
BEGIN
  v_user_id := auth.uid();

  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  -- System admins can always create schools
  IF v_user_role = 'admin' THEN
    NULL; -- allowed, fall through
  ELSIF v_user_role = 'teacher' THEN
    -- Teachers must hold an active school-plan subscription
    IF NOT EXISTS (
      SELECT 1
      FROM subscriptions
      WHERE teacher_id = v_user_id
        AND plan_type   = 'school'
        AND status      IN ('active', 'trialing')
      LIMIT 1
    ) THEN
      RETURN json_build_object(
        'success', false,
        'message', 'A school plan subscription is required to create a school'
      );
    END IF;
  ELSE
    RETURN json_build_object('success', false, 'message', 'Only teachers with a school plan can create schools');
  END IF;

  -- Caller must not already belong to a school
  SELECT school_id INTO v_existing_school_id
  FROM school_members WHERE user_id = v_user_id LIMIT 1;

  IF v_existing_school_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'message', 'You are already a member of a school');
  END IF;

  -- Validate name
  IF p_name IS NULL OR TRIM(p_name) = '' THEN
    RETURN json_build_object('success', false, 'message', 'School name cannot be empty');
  END IF;

  -- Generate unique 6-char join code
  LOOP
    v_join_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM schools WHERE join_code = v_join_code);
  END LOOP;

  -- Create school
  INSERT INTO schools (name, join_code, created_by)
  VALUES (TRIM(p_name), v_join_code, v_user_id)
  RETURNING id INTO v_school_id;

  -- Add creator as school admin
  INSERT INTO school_members (school_id, user_id, school_role)
  VALUES (v_school_id, v_user_id, 'admin');

  RETURN json_build_object(
    'success', true,
    'school_id', v_school_id,
    'join_code', v_join_code,
    'message', 'School created successfully'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION create_school(TEXT) TO authenticated;
