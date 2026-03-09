-- ============================================================
-- MIGRATION 083: Prevent system admins from being school members
-- - get_assignable_teachers: only users.role = 'teacher'
-- - bulk_assign_teachers_to_school: only users.role = 'teacher'
-- - auto_assign_teacher_to_school trigger: skip system admins
-- - Remove any existing system admin accounts from school_members
-- ============================================================

-- Remove system admins already in school_members
DELETE FROM school_members sm
WHERE EXISTS (
  SELECT 1 FROM users u WHERE u.id = sm.user_id AND u.role = 'admin'
);

-- ============================================================
-- FUNCTION: get_assignable_teachers (updated)
-- Only returns users with role = 'teacher'
-- ============================================================
CREATE OR REPLACE FUNCTION get_assignable_teachers(p_school_id UUID)
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
    'teachers', (
      SELECT json_agg(
        json_build_object(
          'user_id', u.id,
          'name', u.name,
          'email', u.email,
          'class_count', (
            SELECT COUNT(*) FROM classes c
            WHERE c.teacher_id = u.id AND c.archived = false
          )
        )
        ORDER BY u.name ASC
      )
      FROM users u
      WHERE u.role = 'teacher'
        AND u.id NOT IN (
          SELECT sm.user_id FROM school_members sm WHERE sm.school_id = p_school_id
        )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: bulk_assign_teachers_to_school (updated)
-- Only adds users with role = 'teacher'
-- ============================================================
CREATE OR REPLACE FUNCTION bulk_assign_teachers_to_school(p_school_id UUID, p_user_ids UUID[])
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_uid UUID;
  v_added INT := 0;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM schools WHERE id = p_school_id) THEN
    RETURN json_build_object('success', false, 'message', 'School not found');
  END IF;

  FOREACH v_uid IN ARRAY p_user_ids
  LOOP
    INSERT INTO school_members (school_id, user_id, school_role)
    SELECT p_school_id, v_uid, 'teacher'
    FROM users u
    WHERE u.id = v_uid
      AND u.role = 'teacher'
      AND NOT EXISTS (
        SELECT 1 FROM school_members sm
        WHERE sm.school_id = p_school_id AND sm.user_id = v_uid
      )
    ON CONFLICT (school_id, user_id) DO NOTHING;

    IF FOUND THEN
      v_added := v_added + 1;
    END IF;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'added', v_added,
    'message', v_added || ' teacher' || CASE WHEN v_added != 1 THEN 's' ELSE '' END || ' assigned to school'
  );
END;
$$;

-- ============================================================
-- TRIGGER FUNCTION: auto_assign_teacher_to_school (updated)
-- Skip if the class teacher is a system admin
-- ============================================================
CREATE OR REPLACE FUNCTION auto_assign_teacher_to_school()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_id   UUID;
  v_teacher_role TEXT;
  v_school_id    UUID;
BEGIN
  SELECT teacher_id INTO v_teacher_id FROM classes WHERE id = NEW.id;

  SELECT role INTO v_teacher_role FROM users WHERE id = v_teacher_id;

  -- Do not auto-assign system admins to schools
  IF v_teacher_role != 'teacher' THEN
    RETURN NEW;
  END IF;

  SELECT school_id INTO v_school_id
  FROM school_members
  WHERE user_id = v_teacher_id
  LIMIT 1;

  IF v_school_id IS NULL THEN
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;
