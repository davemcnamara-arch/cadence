-- ============================================================
-- MIGRATION 076: Restrict school creation to admin role only
-- School setup is a monetized feature; only admins can create
-- schools. Teachers can still join via join code.
-- ============================================================

CREATE OR REPLACE FUNCTION create_school(p_name TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role TEXT;
  v_user_id UUID;
  v_school_id UUID;
  v_join_code TEXT;
  v_existing_school_id UUID;
BEGIN
  v_user_id := auth.uid();

  -- Only admins can create schools (monetized feature)
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;
  IF v_user_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Only admins can create schools');
  END IF;

  -- Check caller isn't already in a school
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
