-- Database function to get student detail data for teachers
-- This bypasses RLS policies to show student progress and songs

CREATE OR REPLACE FUNCTION public.get_student_detail(
  p_student_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSON;
BEGIN
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
    -- Return empty structure on error
    RETURN json_build_object('progress', '[]'::json, 'songs', '[]'::json);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_student_detail(UUID) TO authenticated;
