-- ============================================================
-- MIGRATION 149: Restore deleted_at filter in get_student_detail
--
-- Problem:
--   Migration 135 rewrote get_student_detail to expose
--   custom_instrument_name, but accidentally dropped the
--   AND ss.deleted_at IS NULL filter that migration 119 had
--   added to the songs sub-query.
--
--   As a result, soft-deleted student_songs (deleted_at IS NOT NULL)
--   reappear in the student preview UI.  When a teacher then clicks
--   "Remove" on one of these phantom songs, remove_student_song
--   can't find the row (it still correctly queries with
--   AND deleted_at IS NULL) and returns HTTP 400
--   "Student song not found".
--
-- Fix:
--   Re-add AND ss.deleted_at IS NULL to the songs sub-query in
--   get_student_detail so soft-deleted songs are never returned
--   to the UI in the first place.
-- ============================================================

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

  SELECT json_build_object(
    'progress', (
      SELECT COALESCE(json_agg(
        json_build_object(
          'id',                     sp.id,
          'user_id',                sp.user_id,
          'instrument_id',          sp.instrument_id,
          'current_level',          sp.current_level,
          'current_branch',         sp.current_branch,
          'custom_instrument_name', sp.custom_instrument_name,
          'instruments', json_build_object(
            'id',   i.id,
            'name', COALESCE(sp.custom_instrument_name, i.name),
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
            'name', COALESCE(
              (SELECT sp2.custom_instrument_name FROM student_progress sp2
               WHERE sp2.user_id = ss.user_id AND sp2.instrument_id = ss.instrument_id
               LIMIT 1),
              i.name
            ),
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
        AND ss.deleted_at IS NULL
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

GRANT EXECUTE ON FUNCTION public.get_student_detail(UUID) TO authenticated;
