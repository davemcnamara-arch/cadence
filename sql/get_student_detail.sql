-- Database function to get student detail data for teachers
-- This bypasses RLS policies to show student progress and songs
-- SECURITY: Requires authorization check - user must be student or their teacher

CREATE OR REPLACE FUNCTION public.get_student_detail(
  p_student_id UUID
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
  -- Get the current user
  v_current_user_id := auth.uid();

  -- Check authorization: user must be either:
  -- 1. The student themselves, OR
  -- 2. A teacher with the student in their class
  SELECT (
    v_current_user_id = p_student_id
    OR
    EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = p_student_id
    )
  ) INTO v_is_authorized;

  -- Deny access if not authorized
  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student''s data';
  END IF;

  -- Get student's progress and songs in one query
  SELECT json_build_object(
    'progress', (
      SELECT json_agg(
        json_build_object(
          'id', sp.id,
          'user_id', sp.user_id,
          'instrument_id', sp.instrument_id,
          'current_level', sp.current_level,
          'current_branch', sp.current_branch,
          'instruments', json_build_object(
            'id', i.id,
            'name', i.name,
            'icon', i.icon
          )
        )
      )
      FROM student_progress sp
      JOIN instruments i ON i.id = sp.instrument_id
      WHERE sp.user_id = p_student_id
    ),
    'songs', (
      SELECT json_agg(
        json_build_object(
          'id', ss.id,
          'user_id', ss.user_id,
          'song_id', ss.song_id,
          'instrument_id', ss.instrument_id,
          'status', ss.status,
          'date_started', ss.date_started,
          'date_completed', ss.date_completed,
          'songs', json_build_object(
            'id', s.id,
            'title', s.title,
            'artist', s.artist,
            'chords_url', s.chords_url,
            'tutorial_url', s.tutorial_url,
            'youtube_url', s.youtube_url
          ),
          'instruments', json_build_object(
            'id', i.id,
            'name', i.name,
            'icon', i.icon
          ),
          'resource_ratings', json_build_object(
            'chords', COALESCE((
              SELECT json_agg(rr.chords_rating)
              FROM resource_ratings rr
              WHERE rr.student_song_id = ss.id AND rr.chords_rating IS NOT NULL
            ), '[]'::json),
            'tutorial', COALESCE((
              SELECT json_agg(rr.tutorial_rating)
              FROM resource_ratings rr
              WHERE rr.student_song_id = ss.id AND rr.tutorial_rating IS NOT NULL
            ), '[]'::json)
          )
        )
        ORDER BY ss.date_started DESC
      )
      FROM student_songs ss
      JOIN songs s ON s.id = ss.song_id
      JOIN instruments i ON i.id = ss.instrument_id
      WHERE ss.user_id = p_student_id
    )
  )
  INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    -- Re-raise permission denied errors
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    -- Return empty structure on other errors
    RETURN json_build_object('progress', '[]'::json, 'songs', '[]'::json);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_student_detail(UUID) TO authenticated;
