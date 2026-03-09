-- ============================================================
-- MIGRATION 077: All teachers automatically see school data
-- No longer requires school_members membership to view school.
-- school_role is derived from the user's system role.
-- ============================================================

-- ============================================================
-- FUNCTION: get_my_school
-- Returns the school for any teacher/admin (no join required)
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_school()
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

  -- Only teachers and admins can see school data
  IF v_user_role NOT IN ('teacher', 'admin') THEN
    RETURN NULL;
  END IF;

  -- Return the first school in the system (school_role derived from system role)
  SELECT json_build_object(
    'id', s.id,
    'name', s.name,
    'join_code', s.join_code,
    'created_at', s.created_at,
    'school_role', v_user_role
  ) INTO v_result
  FROM schools s
  ORDER BY s.created_at ASC
  LIMIT 1;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: get_school_dashboard
-- Any teacher/admin can access; teacher list = all teachers
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
          'school_role', u.role,
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
        ORDER BY u.role DESC, u.name ASC
      )
      FROM users u
      WHERE u.role IN ('teacher', 'admin')
    ),
    'stats', (
      SELECT json_build_object(
        'teacher_count', (
          SELECT COUNT(*) FROM users WHERE role = 'teacher'
        ),
        'class_count', (
          SELECT COUNT(*) FROM classes c
          JOIN users u ON u.id = c.teacher_id
          WHERE u.role IN ('teacher', 'admin') AND c.archived = false
        ),
        'student_count', (
          SELECT COUNT(DISTINCT cm.user_id)
          FROM classes c
          JOIN users u ON u.id = c.teacher_id
          JOIN class_members cm ON cm.class_id = c.id
          WHERE u.role IN ('teacher', 'admin') AND c.archived = false
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
              JOIN users u ON u.id = c.teacher_id
              JOIN class_members cm ON cm.class_id = c.id
              WHERE u.role IN ('teacher', 'admin')
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
-- Any teacher/admin can access
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
        JOIN users u2 ON u2.id = c.teacher_id
        JOIN class_members cm ON cm.class_id = c.id
        WHERE u2.role IN ('teacher', 'admin') AND c.archived = false
      ) class_data
      JOIN users u ON u.id = class_data.user_id
      JOIN classes c ON c.name = class_data.name AND c.teacher_id = class_data.teacher_id
      JOIN users t ON t.id = class_data.teacher_id
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;
