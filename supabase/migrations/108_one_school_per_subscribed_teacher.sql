-- ============================================================
-- MIGRATION 108: One school per subscribed teacher; admins unlimited
--
-- Clarifies the school-creation rules:
--   - System admins  → unlimited schools (no membership check)
--   - Subscribed teachers → exactly one school
--                           (blocked if already a member of any school)
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
BEGIN
  v_user_id := auth.uid();

  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role = 'admin' THEN
    -- System admin: no restrictions
    NULL;

  ELSIF v_user_role = 'teacher' THEN
    -- Must have an active school-plan subscription
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

    -- Teachers are limited to one school
    IF EXISTS (
      SELECT 1 FROM school_members WHERE user_id = v_user_id LIMIT 1
    ) THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Your school plan includes one school. Contact support to add more.'
      );
    END IF;

  ELSE
    RETURN json_build_object('success', false, 'message', 'Only teachers with a school plan can create schools');
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

  -- Create school and add creator as admin
  INSERT INTO schools (name, join_code, created_by)
  VALUES (TRIM(p_name), v_join_code, v_user_id)
  RETURNING id INTO v_school_id;

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
