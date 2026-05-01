-- Fix get_trending_songs excluding songs with no primary instrument.
--
-- Migration 129 introduced an INNER JOIN on instruments via s.instrument_id
-- for the display instrument name. Songs with instrument_id = NULL were
-- silently dropped from results. Since the trending strip doesn't display
-- the instrument column, a LEFT JOIN is sufficient.

CREATE OR REPLACE FUNCTION get_trending_songs(
  limit_count       INT,
  instrument_filter TEXT DEFAULT NULL,
  level_filter      INT  DEFAULT NULL
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
    pi.name              AS instrument,
    COUNT(ss.id)::BIGINT AS trending_score
  FROM student_songs ss
  JOIN songs s         ON s.id   = ss.song_id
  JOIN instruments si  ON si.id  = ss.instrument_id   -- student's chosen instrument (for filtering)
  LEFT JOIN instruments pi ON pi.id = s.instrument_id  -- song's primary instrument (for display only)
  WHERE ss.status = 'learning'
    AND ss.deleted_at IS NULL
    AND s.deleted_at IS NULL
    AND (instrument_filter IS NULL OR si.name ILIKE instrument_filter)
    AND (
      level_filter IS NULL
      OR s.suggested_level = level_filter
      OR EXISTS (
        SELECT 1
        FROM song_ratings sr
        JOIN instruments ri ON ri.id = sr.instrument_id
        WHERE sr.song_id = s.id
          AND sr.assessed_level = level_filter
          AND (instrument_filter IS NULL OR ri.name ILIKE instrument_filter)
      )
    )
  GROUP BY s.id, s.title, s.artist, pi.name
  ORDER BY trending_score DESC
  LIMIT limit_count;
END;
$$;

GRANT EXECUTE ON FUNCTION get_trending_songs(INT, TEXT, INT) TO authenticated;
