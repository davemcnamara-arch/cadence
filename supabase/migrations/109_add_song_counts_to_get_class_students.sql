-- Add songs_learning and songs_mastered counts to get_class_students RPC.
-- Previously, exportClassData() queried student_songs directly via the
-- Supabase client for each student, which failed due to RLS/stale-session
-- issues and returned 0 for every row.  Running the counts inside the
-- SECURITY DEFINER function (same pattern as get_school_students) fixes this.

CREATE OR REPLACE FUNCTION public.get_class_students(
  p_class_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_is_authorized BOOLEAN;
  v_result JSON;
BEGIN
  v_current_user_id := auth.uid();

  -- Check authorization: user must be either:
  -- 1. The teacher of this class, OR
  -- 2. A member of this class, OR
  -- 3. An admin
  SELECT (
    EXISTS (
      SELECT 1
      FROM classes c
      WHERE c.id = p_class_id
        AND c.teacher_id = v_current_user_id
    )
    OR
    EXISTS (
      SELECT 1
      FROM class_members cm
      WHERE cm.class_id = p_class_id
        AND cm.user_id = v_current_user_id
    )
    OR
    is_admin()
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this class';
  END IF;

  -- Get all students in the class with their progress and song counts
  SELECT json_agg(
    json_build_object(
      'id', cm.id,
      'class_id', cm.class_id,
      'user_id', cm.user_id,
      'joined_at', cm.joined_at,
      'users', json_build_object(
        'id', u.id,
        'name', u.name,
        'email', u.email
      ),
      'student_progress', (
        SELECT json_agg(
          json_build_object(
            'instrument_id', sp.instrument_id,
            'current_level', sp.current_level,
            'current_branch', sp.current_branch,
            'songs_learning', (
              SELECT COUNT(*)
              FROM student_songs ss
              WHERE ss.user_id = u.id
                AND ss.instrument_id = sp.instrument_id
                AND ss.status = 'learning'
            ),
            'songs_mastered', (
              SELECT COUNT(*)
              FROM student_songs ss
              WHERE ss.user_id = u.id
                AND ss.instrument_id = sp.instrument_id
                AND ss.status = 'mastered'
            )
          )
        )
        FROM student_progress sp
        WHERE sp.user_id = u.id
      )
    )
    ORDER BY u.name
  )
  INTO v_result
  FROM class_members cm
  JOIN users u ON u.id = cm.user_id
  WHERE cm.class_id = p_class_id;

  RETURN COALESCE(v_result, '[]'::json);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    RETURN '[]'::json;
END;
$$;
