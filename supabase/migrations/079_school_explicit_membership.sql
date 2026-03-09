-- ============================================================
-- MIGRATION 079: Explicit teacher assignment to schools
-- - get_school_dashboard now only returns school_members teachers
-- - get_school_students now only returns students from those teachers
-- - New: get_assignable_teachers — teachers not yet in the school
-- - New: bulk_assign_teachers_to_school — admin bulk-adds teachers
-- - Trigger: auto-assign teacher to school on class creation
-- ============================================================

-- ============================================================
-- FUNCTION: get_school_dashboard
-- Only shows teachers explicitly assigned via school_members
-- ============================================================
CREATE OR REPLACE FUNCTION get_school_dashboard(p_school_id UUID)
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

  IF v_user_role NOT IN ('teacher', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Access denied');
  END IF;

  SELECT json_build_object(
    'success', true,
    'teachers', (
      SELECT json_agg(
        json_build_object(
          'user_id', u.id,
          'name', u.name,
          'email', u.email,
          'school_role', sm.school_role,
          'class_count', (
            SELECT COUNT(*) FROM classes c
            WHERE c.teacher_id = u.id AND c.archived = false
          ),
          'student_count', (
            SELECT COUNT(DISTINCT cm.user_id)
            FROM classes c
            JOIN class_members cm ON cm.class_id = c.id
            WHERE c.teacher_id = u.id AND c.archived = false
          )
        )
        ORDER BY sm.school_role DESC, u.name ASC
      )
      FROM school_members sm
      JOIN users u ON u.id = sm.user_id
      WHERE sm.school_id = p_school_id
    ),
    'stats', (
      SELECT json_build_object(
        'teacher_count', (
          SELECT COUNT(*) FROM school_members WHERE school_id = p_school_id
        ),
        'class_count', (
          SELECT COUNT(*) FROM classes c
          JOIN school_members sm ON sm.user_id = c.teacher_id AND sm.school_id = p_school_id
          WHERE c.archived = false
        ),
        'student_count', (
          SELECT COUNT(DISTINCT cm.user_id)
          FROM classes c
          JOIN school_members sm ON sm.user_id = c.teacher_id AND sm.school_id = p_school_id
          JOIN class_members cm ON cm.class_id = c.id
          WHERE c.archived = false
        ),
        'instrument_counts', (
          SELECT json_agg(
            json_build_object('name', i.name, 'icon', i.icon, 'count', sp_counts.cnt)
            ORDER BY sp_counts.cnt DESC
          )
          FROM (
            SELECT sp.instrument_id, COUNT(DISTINCT sp.user_id) AS cnt
            FROM student_progress sp
            WHERE sp.user_id IN (
              SELECT DISTINCT cm.user_id
              FROM classes c
              JOIN school_members sm ON sm.user_id = c.teacher_id AND sm.school_id = p_school_id
              JOIN class_members cm ON cm.class_id = c.id
              WHERE c.archived = false
            )
            GROUP BY sp.instrument_id
          ) sp_counts
          JOIN instruments i ON i.id = sp_counts.instrument_id
        )
      )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: get_school_students
-- Only returns students from assigned teachers' classes
-- ============================================================
CREATE OR REPLACE FUNCTION get_school_students(p_school_id UUID)
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

  IF v_user_role NOT IN ('teacher', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Access denied');
  END IF;

  SELECT json_build_object(
    'success', true,
    'students', (
      SELECT json_agg(
        json_build_object(
          'user_id', u.id,
          'name', u.name,
          'email', u.email,
          'class_name', c.name,
          'teacher_name', t.name,
          'instruments', (
            SELECT json_agg(
              json_build_object(
                'instrument_name', i.name,
                'instrument_icon', i.icon,
                'current_level', sp.current_level
              )
              ORDER BY i.display_order
            )
            FROM student_progress sp
            JOIN instruments i ON i.id = sp.instrument_id
            WHERE sp.user_id = u.id
          ),
          'songs_learning', (
            SELECT COUNT(*) FROM student_songs ss
            WHERE ss.user_id = u.id AND ss.status = 'learning'
          ),
          'songs_mastered', (
            SELECT COUNT(*) FROM student_songs ss
            WHERE ss.user_id = u.id AND ss.status = 'mastered'
          )
        )
        ORDER BY u.name ASC
      )
      FROM (
        SELECT DISTINCT cm.user_id, c.name, c.teacher_id
        FROM classes c
        JOIN school_members sm ON sm.user_id = c.teacher_id AND sm.school_id = p_school_id
        JOIN class_members cm ON cm.class_id = c.id
        WHERE c.archived = false
      ) class_data
      JOIN users u ON u.id = class_data.user_id
      JOIN classes c ON c.name = class_data.name AND c.teacher_id = class_data.teacher_id
      JOIN users t ON t.id = class_data.teacher_id
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: get_assignable_teachers
-- Returns teachers/admins not yet assigned to the school
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
      WHERE u.role IN ('teacher', 'admin')
        AND u.id NOT IN (
          SELECT sm.user_id FROM school_members sm WHERE sm.school_id = p_school_id
        )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: bulk_assign_teachers_to_school
-- Admin assigns multiple teachers to a school at once
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

  -- Verify school exists
  IF NOT EXISTS (SELECT 1 FROM schools WHERE id = p_school_id) THEN
    RETURN json_build_object('success', false, 'message', 'School not found');
  END IF;

  FOREACH v_uid IN ARRAY p_user_ids
  LOOP
    -- Only add users with teacher or admin role; skip if already a member
    INSERT INTO school_members (school_id, user_id, school_role)
    SELECT p_school_id, v_uid, u.role
    FROM users u
    WHERE u.id = v_uid
      AND u.role IN ('teacher', 'admin')
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
-- FUNCTION + TRIGGER: auto-assign teacher to school on class create
-- When a teacher creates a class and they are not yet a school
-- member, add them automatically to the first school.
-- ============================================================
CREATE OR REPLACE FUNCTION auto_assign_teacher_to_school()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_role TEXT;
  v_school_id UUID;
BEGIN
  -- Only act on teacher/admin users
  SELECT role INTO v_teacher_role FROM users WHERE id = NEW.teacher_id;
  IF v_teacher_role NOT IN ('teacher', 'admin') THEN
    RETURN NEW;
  END IF;

  -- Skip if teacher is already in a school
  IF EXISTS (SELECT 1 FROM school_members WHERE user_id = NEW.teacher_id) THEN
    RETURN NEW;
  END IF;

  -- Find the first school in the system
  SELECT id INTO v_school_id FROM schools ORDER BY created_at ASC LIMIT 1;
  IF v_school_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Add teacher to school
  INSERT INTO school_members (school_id, user_id, school_role)
  VALUES (v_school_id, NEW.teacher_id, v_teacher_role)
  ON CONFLICT (school_id, user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_assign_teacher_to_school ON classes;
CREATE TRIGGER trg_auto_assign_teacher_to_school
  AFTER INSERT ON classes
  FOR EACH ROW
  EXECUTE FUNCTION auto_assign_teacher_to_school();
