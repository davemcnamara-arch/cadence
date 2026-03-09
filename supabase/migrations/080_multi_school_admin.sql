-- ============================================================
-- MIGRATION 080: Multi-school support for admins
-- - create_school no longer blocks admins already in a school
-- - get_all_schools returns all schools with basic stats (admin only)
-- ============================================================

-- ============================================================
-- FUNCTION: create_school (updated)
-- Admins can create multiple schools
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
BEGIN
  v_user_id := auth.uid();

  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;
  IF v_user_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Only admins can create schools');
  END IF;

  IF p_name IS NULL OR TRIM(p_name) = '' THEN
    RETURN json_build_object('success', false, 'message', 'School name cannot be empty');
  END IF;

  -- Generate unique 6-char join code
  LOOP
    v_join_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM schools WHERE join_code = v_join_code);
  END LOOP;

  INSERT INTO schools (name, join_code, created_by)
  VALUES (TRIM(p_name), v_join_code, v_user_id)
  RETURNING id INTO v_school_id;

  -- Add creator as school admin (may already be a member of other schools; that's fine)
  INSERT INTO school_members (school_id, user_id, school_role)
  VALUES (v_school_id, v_user_id, 'admin')
  ON CONFLICT (school_id, user_id) DO NOTHING;

  RETURN json_build_object(
    'success', true,
    'school_id', v_school_id,
    'join_code', v_join_code,
    'message', 'School created successfully'
  );
END;
$$;

-- ============================================================
-- FUNCTION: get_all_schools
-- Returns all schools with stats, for admin list view
-- ============================================================
CREATE OR REPLACE FUNCTION get_all_schools()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_result JSON;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  SELECT json_build_object(
    'success', true,
    'schools', (
      SELECT json_agg(
        json_build_object(
          'id', s.id,
          'name', s.name,
          'join_code', s.join_code,
          'created_at', s.created_at,
          'teacher_count', (
            SELECT COUNT(*) FROM school_members sm WHERE sm.school_id = s.id
          ),
          'class_count', (
            SELECT COUNT(*) FROM classes c
            JOIN school_members sm ON sm.user_id = c.teacher_id AND sm.school_id = s.id
            WHERE c.archived = false
          ),
          'student_count', (
            SELECT COUNT(DISTINCT cm.user_id)
            FROM classes c
            JOIN school_members sm ON sm.user_id = c.teacher_id AND sm.school_id = s.id
            JOIN class_members cm ON cm.class_id = c.id
            WHERE c.archived = false
          )
        )
        ORDER BY s.created_at ASC
      )
      FROM schools s
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;
