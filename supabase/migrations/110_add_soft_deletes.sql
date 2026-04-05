-- Add soft delete support to songs and student_songs
-- Instead of permanently deleting rows, we set deleted_at to the current timestamp.
-- Rows with deleted_at IS NOT NULL are treated as deleted and filtered from all queries.
-- To recover a row: UPDATE songs SET deleted_at = NULL WHERE id = '<id>';
--                   UPDATE student_songs SET deleted_at = NULL WHERE id = '<id>';

ALTER TABLE songs ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE student_songs ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- Update remove_student_song to soft delete instead of hard delete
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
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = v_student_id
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

  -- Soft delete instead of hard delete
  UPDATE student_songs
  SET deleted_at = NOW()
  WHERE id = p_student_song_id;

  RETURN v_result;
END;
$$;

-- Update remove_instrument_for_student to soft delete student_songs
CREATE OR REPLACE FUNCTION remove_instrument_for_student(
  p_student_id    UUID,
  p_instrument_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_caller_id UUID;
  v_has_access BOOLEAN;
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

  -- Soft delete student songs for this instrument
  UPDATE student_songs
  SET deleted_at = NOW()
  WHERE user_id = p_student_id
    AND instrument_id = p_instrument_id
    AND deleted_at IS NULL;

  -- Hard delete the progress record (no meaningful data loss, just a counter row)
  DELETE FROM student_progress
  WHERE user_id = p_student_id AND instrument_id = p_instrument_id;

  RETURN json_build_object('success', true);
END;
$$;

-- Update get_trending_songs to exclude soft-deleted songs and student_songs
CREATE OR REPLACE FUNCTION get_trending_songs(
  days_back         INT,
  limit_count       INT,
  instrument_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
  song_id        UUID,
  title          TEXT,
  artist         TEXT,
  instrument     TEXT,
  trending_score BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id                 AS song_id,
    s.title              AS title,
    s.artist             AS artist,
    i.name               AS instrument,
    COUNT(ss.id)::BIGINT AS trending_score
  FROM songs s
  JOIN instruments i    ON i.id     = s.instrument_id
  JOIN student_songs ss ON ss.song_id = s.id
  WHERE ss.date_started >= NOW() - (days_back || ' days')::INTERVAL
    AND (instrument_filter IS NULL OR i.name ILIKE instrument_filter)
    AND s.deleted_at IS NULL
    AND ss.deleted_at IS NULL
  GROUP BY s.id, s.title, s.artist, i.name
  ORDER BY trending_score DESC
  LIMIT limit_count;
END;
$$;

-- Update find_similar_songs to exclude soft-deleted songs
DROP FUNCTION IF EXISTS find_similar_songs(TEXT, TEXT, FLOAT, INTEGER);
CREATE OR REPLACE FUNCTION find_similar_songs(
  p_title      TEXT,
  p_artist     TEXT,
  p_threshold  FLOAT   DEFAULT 0.3,
  p_limit      INTEGER DEFAULT 10
)
RETURNS TABLE (
  id          UUID,
  title       TEXT,
  artist      TEXT,
  similarity  FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'extensions, public'
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.title,
    s.artist,
    GREATEST(
      extensions.similarity(s.title,  p_title),
      extensions.similarity(s.artist, p_artist)
    ) AS similarity
  FROM songs s
  WHERE (
    extensions.similarity(s.title,  p_title)  >= p_threshold
    OR extensions.similarity(s.artist, p_artist) >= p_threshold
  )
  AND s.deleted_at IS NULL
  ORDER BY similarity DESC
  LIMIT p_limit;
END;
$$;
