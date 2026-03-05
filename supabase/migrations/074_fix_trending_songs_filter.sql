-- Fix get_trending_songs to filter by the instrument students are actually
-- learning the song for (student_songs.instrument_id) rather than the song's
-- primary instrument tag (songs.instrument_id), which could mismatch the
-- displayed instrument/level from song_ratings.
--
-- Also adds level_filter so the trending strip only shows songs at the
-- currently-active level (or all levels when no level is selected).

CREATE OR REPLACE FUNCTION get_trending_songs(
  days_back         INT,
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
    i.name               AS instrument,
    COUNT(ss.id)::BIGINT AS trending_score
  FROM student_songs ss
  JOIN songs s       ON s.id  = ss.song_id
  JOIN instruments i ON i.id  = ss.instrument_id
  WHERE ss.date_started >= NOW() - (days_back || ' days')::INTERVAL
    AND (instrument_filter IS NULL OR i.name ILIKE instrument_filter)
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
  GROUP BY s.id, s.title, s.artist, i.name
  ORDER BY trending_score DESC
  LIMIT limit_count;
END;
$$;

GRANT EXECUTE ON FUNCTION get_trending_songs(INT, INT, TEXT, INT) TO authenticated;
