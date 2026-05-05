-- Update RPCs to support the "Other Instrument" feature:
--
-- 1. add_instrument_for_student  — accepts optional p_custom_instrument_name; allows
--    multiple "Other Instrument" rows per student (distinguished by custom name)
-- 2. remove_instrument_for_student — now takes p_progress_id (student_progress.id)
--    so callers can target a specific row even when a student has multiple "Other" rows
-- 3. get_student_detail         — includes custom_instrument_name in the progress payload
--    and uses it as the display name when set
-- 4. get_teacher_student_songs  — shows custom_instrument_name when available
-- 5. get_song_students_for_teacher — shows custom_instrument_name when available

-- ============================================================================
-- 1. add_instrument_for_student  (adds p_custom_instrument_name parameter)
-- ============================================================================
DROP FUNCTION IF EXISTS add_instrument_for_student(UUID, UUID);

CREATE OR REPLACE FUNCTION add_instrument_for_student(
  p_student_id            UUID,
  p_instrument_id         UUID,
  p_custom_instrument_name TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_caller_id UUID;
  v_has_access BOOLEAN;
  v_result     JSON;
BEGIN
  v_caller_id := auth.uid();

  SELECT (
    v_caller_id = p_student_id
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_caller_id
        AND cm.user_id = p_student_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- For standard instruments: prevent duplicates by instrument_id alone.
  -- For "Other Instrument": prevent duplicates by (instrument_id, custom_instrument_name).
  IF p_custom_instrument_name IS NULL THEN
    IF EXISTS (
      SELECT 1 FROM student_progress
      WHERE user_id = p_student_id
        AND instrument_id = p_instrument_id
        AND custom_instrument_name IS NULL
    ) THEN
      RAISE EXCEPTION 'Student already has this instrument';
    END IF;
  ELSE
    IF EXISTS (
      SELECT 1 FROM student_progress
      WHERE user_id = p_student_id
        AND instrument_id = p_instrument_id
        AND custom_instrument_name = p_custom_instrument_name
    ) THEN
      RAISE EXCEPTION 'Student already has this instrument';
    END IF;
  END IF;

  INSERT INTO student_progress (user_id, instrument_id, current_level, custom_instrument_name)
  VALUES (p_student_id, p_instrument_id, 1, p_custom_instrument_name)
  RETURNING json_build_object(
    'id',                    id,
    'user_id',               user_id,
    'instrument_id',         instrument_id,
    'current_level',         current_level,
    'current_branch',        current_branch,
    'custom_instrument_name', custom_instrument_name,
    'date_started',          date_started,
    'last_updated',          last_updated
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION add_instrument_for_student(UUID, UUID, TEXT) TO authenticated;


-- ============================================================================
-- 2. remove_instrument_for_student  (now uses p_progress_id instead of p_instrument_id)
-- ============================================================================
DROP FUNCTION IF EXISTS remove_instrument_for_student(UUID, UUID);

CREATE OR REPLACE FUNCTION remove_instrument_for_student(
  p_student_id  UUID,
  p_progress_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_caller_id   UUID;
  v_has_access  BOOLEAN;
  v_instrument_id UUID;
BEGIN
  v_caller_id := auth.uid();

  SELECT (
    v_caller_id = p_student_id
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_caller_id
        AND cm.user_id = p_student_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- Fetch instrument_id so we can cascade-delete student_songs
  SELECT instrument_id INTO v_instrument_id
  FROM student_progress
  WHERE id = p_progress_id AND user_id = p_student_id;

  IF v_instrument_id IS NULL THEN
    RAISE EXCEPTION 'Progress record not found';
  END IF;

  -- Delete student_songs only if this is the last progress row for this instrument
  -- (a student could have two "Other" rows sharing the same instrument_id)
  IF (
    SELECT COUNT(*) FROM student_progress
    WHERE user_id = p_student_id AND instrument_id = v_instrument_id
  ) = 1 THEN
    DELETE FROM student_songs
    WHERE user_id = p_student_id AND instrument_id = v_instrument_id;
  END IF;

  DELETE FROM student_progress
  WHERE id = p_progress_id AND user_id = p_student_id;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION remove_instrument_for_student(UUID, UUID) TO authenticated;


-- ============================================================================
-- 3. get_student_detail — include custom_instrument_name; use it as display name
-- ============================================================================
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


-- ============================================================================
-- 4. get_teacher_student_songs — show custom_instrument_name when available
-- ============================================================================
DROP FUNCTION IF EXISTS get_teacher_student_songs();

CREATE OR REPLACE FUNCTION get_teacher_student_songs()
RETURNS TABLE (
  student_song_id    UUID,
  student_id         UUID,
  student_name       TEXT,
  song_id            UUID,
  title              TEXT,
  artist             TEXT,
  youtube_url        TEXT,
  chords_url         TEXT,
  bass_tab_url       TEXT,
  drum_notation_url  TEXT,
  instrument_id      UUID,
  instrument_name    TEXT,
  instrument_icon    TEXT,
  class_id           UUID,
  class_name         TEXT,
  date_started       DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (ss.id)
    ss.id                  AS student_song_id,
    u.id                   AS student_id,
    u.name                 AS student_name,
    so.id                  AS song_id,
    so.title               AS title,
    so.artist              AS artist,
    so.youtube_url         AS youtube_url,
    so.chords_url          AS chords_url,
    so.bass_tab_url        AS bass_tab_url,
    so.drum_notation_url   AS drum_notation_url,
    i.id                   AS instrument_id,
    COALESCE(
      (SELECT sp.custom_instrument_name FROM student_progress sp
       WHERE sp.user_id = ss.user_id AND sp.instrument_id = ss.instrument_id
       LIMIT 1),
      i.name
    )                      AS instrument_name,
    i.icon                 AS instrument_icon,
    c.id                   AS class_id,
    c.name                 AS class_name,
    ss.date_started::DATE  AS date_started
  FROM student_songs ss
  JOIN users u          ON u.id  = ss.user_id
  JOIN songs so         ON so.id = ss.song_id
  JOIN instruments i    ON i.id  = ss.instrument_id
  JOIN class_members cm ON cm.user_id = u.id
  JOIN classes c        ON c.id  = cm.class_id
  WHERE ss.status = 'learning'
    AND c.teacher_id = auth.uid()
    AND c.archived IS NOT TRUE
  ORDER BY ss.id, c.id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_teacher_student_songs() TO authenticated;


-- ============================================================================
-- 5. get_song_students_for_teacher — show custom_instrument_name when available
-- ============================================================================
CREATE OR REPLACE FUNCTION get_song_students_for_teacher(
  p_song_id UUID,
  p_include_archived BOOLEAN DEFAULT false
)
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  status TEXT,
  instrument_id UUID,
  instrument_name TEXT,
  instrument_icon TEXT,
  date_started TIMESTAMPTZ,
  date_completed TIMESTAMPTZ,
  class_name TEXT,
  class_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin')) THEN
    RAISE EXCEPTION 'Permission denied: must be a teacher or admin';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (ss.user_id, ss.instrument_id)
    ss.user_id,
    u.name,
    ss.status,
    ss.instrument_id,
    COALESCE(
      (SELECT sp.custom_instrument_name FROM student_progress sp
       WHERE sp.user_id = ss.user_id AND sp.instrument_id = ss.instrument_id
       LIMIT 1),
      i.name
    ) AS instrument_name,
    i.icon AS instrument_icon,
    ss.date_started,
    ss.date_completed,
    c.name AS class_name,
    c.id AS class_id
  FROM student_songs ss
  INNER JOIN users u ON ss.user_id = u.id
  INNER JOIN instruments i ON ss.instrument_id = i.id
  INNER JOIN class_members cm ON ss.user_id = cm.user_id
  INNER JOIN classes c ON cm.class_id = c.id
  WHERE ss.song_id = p_song_id
    AND c.teacher_id = auth.uid()
    AND (p_include_archived = true OR c.archived IS NOT TRUE)
  ORDER BY ss.user_id, ss.instrument_id, ss.date_started DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_song_students_for_teacher(UUID, BOOLEAN) TO authenticated;
