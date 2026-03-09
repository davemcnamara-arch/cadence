-- ============================================================
-- MIGRATION 088: Multi-school teacher support
--
-- Problem: join_school() blocked teachers from joining a second
-- school ("You are already a member of a school"). This prevents
-- a teacher who belongs to School A from also being assigned to
-- School B.
--
-- Fix:
--   1. Update join_school() to only block duplicate membership
--      in the *same* school, not any school.
--   2. Add get_my_schools() which returns all schools the caller
--      belongs to (array), used by the teacher school view and
--      the "Add New Class" school selector.
-- ============================================================

-- ============================================================
-- 1. Update join_school()
--    Old behaviour: blocked if user was in ANY school.
--    New behaviour: blocked only if already in THIS school.
-- ============================================================
CREATE OR REPLACE FUNCTION join_school(p_join_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_role TEXT;
  v_user_id   UUID;
  v_school_id UUID;
  v_school_name TEXT;
BEGIN
  v_user_id := auth.uid();

  -- Only teachers can join schools (admins are not school members per migration 083)
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;
  IF v_user_role != 'teacher' THEN
    RETURN json_build_object('success', false, 'message', 'Only teachers can join schools');
  END IF;

  -- Find school by join code (case-insensitive)
  SELECT id, name INTO v_school_id, v_school_name
  FROM schools WHERE UPPER(join_code) = UPPER(TRIM(p_join_code));

  IF v_school_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid school code');
  END IF;

  -- Block only if already a member of THIS specific school
  IF EXISTS (
    SELECT 1 FROM school_members
    WHERE school_id = v_school_id AND user_id = v_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'You are already a member of this school');
  END IF;

  -- Add teacher to school
  INSERT INTO school_members (school_id, user_id, school_role)
  VALUES (v_school_id, v_user_id, 'teacher');

  RETURN json_build_object(
    'success', true,
    'school_id', v_school_id,
    'school_name', v_school_name,
    'message', format('Joined %s successfully', v_school_name)
  );
END;
$$;

-- ============================================================
-- 2. Add get_my_schools()
--    Returns a JSON array of all schools the caller belongs to,
--    ordered by join date (oldest first).
--    Returns [] when the user is not in any school.
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_schools()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_result  JSON;
BEGIN
  v_user_id := auth.uid();

  SELECT COALESCE(
    json_agg(
      json_build_object(
        'id',          s.id,
        'name',        s.name,
        'join_code',   s.join_code,
        'school_role', sm.school_role,
        'joined_at',   sm.joined_at
      )
      ORDER BY sm.joined_at ASC
    ),
    '[]'::json
  ) INTO v_result
  FROM school_members sm
  JOIN schools s ON s.id = sm.school_id
  WHERE sm.user_id = v_user_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION join_school(TEXT)  TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_schools()   TO authenticated;
