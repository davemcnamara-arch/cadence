-- ============================================================
-- MIGRATION 124: Add songs_learning and songs_mastered to
--               get_school_dashboard stats
--
-- Adds school-wide song counts (excluding soft-deleted rows)
-- to the stats object returned by get_school_dashboard.
-- ============================================================

CREATE OR REPLACE FUNCTION get_school_dashboard(p_school_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID;
  v_user_role TEXT;
  v_result    JSON;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role NOT IN ('teacher', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Access denied');
  END IF;

  SELECT json_build_object(
    'success', true,
    'shared_class_visibility', (
      SELECT shared_class_visibility FROM schools WHERE id = p_school_id
    ),
    'teachers', (
      SELECT json_agg(
        json_build_object(
          'user_id',      u.id,
          'name',         u.name,
          'email',        u.email,
          'school_role',  sm.school_role,
          'class_count',  (
            SELECT COUNT(*)
            FROM classes c
            WHERE c.teacher_id = u.id
              AND c.school_id = p_school_id
              AND c.archived = false
          ),
          'student_count', (
            SELECT COUNT(DISTINCT cm.user_id)
            FROM classes c
            JOIN class_members cm ON cm.class_id = c.id
            WHERE c.teacher_id = u.id
              AND c.school_id = p_school_id
              AND c.archived = false
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
          SELECT COUNT(*)
          FROM classes c
          WHERE c.school_id = p_school_id
            AND c.archived = false
        ),
        'student_count', (
          SELECT COUNT(*) FROM school_students WHERE school_id = p_school_id
        ),
        'songs_learning', (
          SELECT COUNT(*)
          FROM student_songs ss
          WHERE ss.user_id IN (
            SELECT user_id FROM school_students WHERE school_id = p_school_id
          )
            AND ss.status = 'learning'
            AND ss.deleted_at IS NULL
        ),
        'songs_mastered', (
          SELECT COUNT(*)
          FROM student_songs ss
          WHERE ss.user_id IN (
            SELECT user_id FROM school_students WHERE school_id = p_school_id
          )
            AND ss.status = 'mastered'
            AND ss.deleted_at IS NULL
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
              SELECT user_id FROM school_students WHERE school_id = p_school_id
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

GRANT EXECUTE ON FUNCTION get_school_dashboard(UUID) TO authenticated;
