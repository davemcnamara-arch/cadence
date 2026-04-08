-- Database function to get student detail data for teachers
-- This bypasses RLS policies to show student progress and songs
-- SECURITY: Requires authorisation check - caller must be the student,
--           a global admin, their direct teacher, or a peer teacher
--           in the same school.

CREATE OR REPLACE FUNCTION public.get_student_detail(
  p_student_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id     UUID;
  v_is_authorized BOOLEAN;
  v_result        JSON;
BEGIN
  v_caller_id := auth.uid();

  -- Authorisation: caller must be one of:
  --   1. The student themselves
  --   2. A global admin
  --   3. A teacher who directly teaches a class containing the student
  --   4. A peer teacher who is a school member of any school
  --      that contains one of the student's classes
  SELECT (
    v_caller_id = p_student_id

    OR is_admin()

    OR EXISTS (
      SELECT 1
      FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      WHERE cm.user_id = p_student_id
        AND c.teacher_id = v_caller_id
    )

    OR EXISTS (
      SELECT 1
      FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      JOIN school_members sm ON sm.school_id = c.school_id
      WHERE cm.user_id = p_student_id
        AND sm.user_id = v_caller_id
    )
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student''s data';
  END IF;

  -- Return both progress (level info) and songs so the UI can display
  -- instrument cards with level badges as well as song lists.
  SELECT json_build_object(
    'progress', (
      SELECT COALESCE(json_agg(
        json_build_object(
          'id',             sp.id,
          'user_id',        sp.user_id,
          'instrument_id',  sp.instrument_id,
          'current_level',  sp.current_level,
          'current_branch', sp.current_branch,
          'instruments', json_build_object(
            'id',   i.id,
            'name', i.name,
            'icon', i.icon
          )
        )
      ), '[]'::json)
      FROM student_progress sp
      JOIN instruments i ON i.id = sp.instrument_id
      WHERE sp.user_id = p_student_id
    ),
    'songs', (
      SELECT COALESCE(json_agg(
        json_build_object(
          'id',             ss.id,
          'user_id',        ss.user_id,
          'song_id',        ss.song_id,
          'instrument_id',  ss.instrument_id,
          'status',         ss.status,
          'date_started',   ss.date_started,
          'date_completed', ss.date_completed,
          'songs', json_build_object(
            'id',                  s.id,
            'title',               s.title,
            'artist',              s.artist,
            'chords_url',          s.chords_url,
            'bass_tab_url',        s.bass_tab_url,
            'drum_notation_url',   s.drum_notation_url,
            'tutorial_url',        s.tutorial_url,
            'youtube_url',         s.youtube_url
          ),
          'instruments', json_build_object(
            'id',   i.id,
            'name', i.name,
            'icon', i.icon
          ),
          'resource_ratings', json_build_object(
            'chords', COALESCE((
              SELECT json_agg(rr.chords_rating)
              FROM resource_ratings rr
              WHERE rr.student_song_id = ss.id
                AND rr.chords_rating IS NOT NULL
            ), '[]'::json),
            'tutorial', COALESCE((
              SELECT json_agg(rr.tutorial_rating)
              FROM resource_ratings rr
              WHERE rr.student_song_id = ss.id
                AND rr.tutorial_rating IS NOT NULL
            ), '[]'::json)
          )
        )
        ORDER BY ss.date_started DESC
      ), '[]'::json)
      FROM student_songs ss
      JOIN songs s ON s.id = ss.song_id
      JOIN instruments i ON i.id = ss.instrument_id
      WHERE ss.user_id = p_student_id
    )
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    RETURN json_build_object('progress', '[]'::json, 'songs', '[]'::json);
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_student_detail(UUID) TO authenticated;
