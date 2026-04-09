-- ============================================================
-- MIGRATION 119: Fix song removal in student preview mode
--
-- Problem 1 (Permission denied - 400):
--   remove_student_song, update_student_song_status, and
--   get_student_song_detail only authorise:
--     1. The student themselves
--     2. A teacher who directly owns a class containing the student
--
--   Migration 118 expanded get_student_detail to also allow
--   peer school teachers and admins to VIEW student data in
--   preview mode. But these mutation functions were not updated
--   to match, so peer school teachers get "Permission denied"
--   (HTTP 400) when trying to remove or update a student's song.
--
-- Problem 2 (Song not found - 400):
--   get_student_detail does not filter soft-deleted student_songs
--   (deleted_at IS NOT NULL). So previously-removed songs still
--   appear in the preview UI. When a teacher then tries to remove
--   one of these already-soft-deleted songs, remove_student_song
--   fails with "Student song not found" because it queries with
--   AND deleted_at IS NULL.
--
-- Fix:
--   1. Expand authorisation in remove_student_song,
--      update_student_song_status, and get_student_song_detail
--      to match the pattern introduced in migration 118:
--        - The student themselves
--        - Global admins (is_admin())
--        - Direct teacher of the student
--        - Peer teacher sharing a school with the student
--
--   2. Add AND ss.deleted_at IS NULL to get_student_detail's
--      songs sub-query so soft-deleted songs are hidden.
-- ============================================================

-- ============================================================
-- 1. Fix remove_student_song
-- ============================================================
CREATE OR REPLACE FUNCTION remove_student_song(
  p_student_song_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_student_id UUID;
  v_has_access BOOLEAN;
  v_result JSON;
BEGIN
  v_current_user_id := auth.uid();

  SELECT user_id INTO v_student_id
  FROM student_songs
  WHERE id = p_student_song_id AND deleted_at IS NULL;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student song not found';
  END IF;

  SELECT (
    v_current_user_id = v_student_id

    OR is_admin()

    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = v_student_id
    )

    OR EXISTS (
      SELECT 1
      FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      JOIN school_members sm ON sm.school_id = c.school_id
      WHERE cm.user_id = v_student_id
        AND sm.user_id = v_current_user_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  SELECT json_build_object(
    'id', id,
    'user_id', user_id,
    'song_id', song_id
  ) INTO v_result
  FROM student_songs
  WHERE id = p_student_song_id;

  -- Soft delete
  UPDATE student_songs
  SET deleted_at = NOW()
  WHERE id = p_student_song_id;

  RETURN v_result;
END;
$$;

-- ============================================================
-- 2. Fix update_student_song_status
-- ============================================================
CREATE OR REPLACE FUNCTION update_student_song_status(
  p_student_song_id UUID,
  p_status TEXT,
  p_date_completed TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_student_id UUID;
  v_has_access BOOLEAN;
  v_result JSON;
BEGIN
  v_current_user_id := auth.uid();

  SELECT user_id INTO v_student_id
  FROM student_songs
  WHERE id = p_student_song_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student song not found';
  END IF;

  SELECT (
    v_current_user_id = v_student_id

    OR is_admin()

    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = v_student_id
    )

    OR EXISTS (
      SELECT 1
      FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      JOIN school_members sm ON sm.school_id = c.school_id
      WHERE cm.user_id = v_student_id
        AND sm.user_id = v_current_user_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  UPDATE student_songs
  SET
    status = p_status,
    date_completed = p_date_completed
  WHERE id = p_student_song_id
  RETURNING json_build_object(
    'id', id,
    'user_id', user_id,
    'song_id', song_id,
    'instrument_id', instrument_id,
    'status', status,
    'date_completed', date_completed
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- 3. Fix get_student_song_detail
-- ============================================================
CREATE OR REPLACE FUNCTION get_student_song_detail(
  p_student_song_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_student_id UUID;
  v_has_access BOOLEAN;
  v_result JSON;
BEGIN
  v_current_user_id := auth.uid();

  SELECT user_id INTO v_student_id
  FROM student_songs
  WHERE id = p_student_song_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student song not found';
  END IF;

  SELECT (
    v_current_user_id = v_student_id

    OR is_admin()

    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = v_student_id
    )

    OR EXISTS (
      SELECT 1
      FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      JOIN school_members sm ON sm.school_id = c.school_id
      WHERE cm.user_id = v_student_id
        AND sm.user_id = v_current_user_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  SELECT json_build_object(
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
      'youtube_url', s.youtube_url,
      'suggested_level', s.suggested_level
    )
  ) INTO v_result
  FROM student_songs ss
  JOIN songs s ON ss.song_id = s.id
  WHERE ss.id = p_student_song_id;

  RETURN v_result;
END;
$$;

-- ============================================================
-- 4. Fix get_student_detail — filter out soft-deleted songs
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
