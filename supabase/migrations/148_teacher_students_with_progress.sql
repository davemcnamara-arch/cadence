-- Returns each of a teacher's students (deduplicated) with instrument and song progress data.
-- Used by the "My Students" view to show richer detail cards.

CREATE OR REPLACE FUNCTION get_teacher_students_with_progress(
  p_school_id UUID DEFAULT NULL
)
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

  SELECT json_build_object(
    'success', true,
    'students', COALESCE((
      SELECT json_agg(
        json_build_object(
          'user_id',       sq.uid,
          'name',          sq.uname,
          'email',         sq.uemail,
          'classes',       sq.class_list,
          'instruments', (
            SELECT json_agg(
              json_build_object(
                'instrument_name', COALESCE(sp.custom_instrument_name, i.name),
                'instrument_icon', i.icon,
                'current_level',   sp.current_level
              )
              ORDER BY i.display_order
            )
            FROM student_progress sp
            JOIN instruments i ON i.id = sp.instrument_id
            WHERE sp.user_id = sq.uid
          ),
          'songs_learning', (
            SELECT COUNT(*) FROM student_songs ss
            WHERE ss.user_id = sq.uid AND ss.status = 'learning'
          ),
          'songs_mastered', (
            SELECT COUNT(*) FROM student_songs ss
            WHERE ss.user_id = sq.uid AND ss.status = 'mastered'
          )
        )
        ORDER BY sq.uname
      )
      FROM (
        SELECT
          u.id    AS uid,
          u.name  AS uname,
          u.email AS uemail,
          json_agg(
            json_build_object('id', c.id, 'name', c.name)
            ORDER BY c.created_at DESC
          ) AS class_list
        FROM users u
        JOIN class_members cm ON cm.user_id = u.id
        JOIN classes c         ON c.id = cm.class_id
        WHERE c.teacher_id = v_user_id
          AND c.archived IS NOT TRUE
          AND (p_school_id IS NULL OR c.school_id = p_school_id)
        GROUP BY u.id, u.name, u.email
      ) sq
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_teacher_students_with_progress(UUID) TO authenticated;
