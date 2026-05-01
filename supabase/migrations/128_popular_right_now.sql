-- Replace time-windowed trending metric with "currently learning" count.
-- Counts students whose status is 'learning' (no time window needed — a song
-- being actively learned by many students is current regardless of when they started).
-- Preserves instrument and level filtering behaviour from migration 074.

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
    i.name               AS instrument,
    COUNT(ss.id)::BIGINT AS trending_score
  FROM student_songs ss
  JOIN songs s       ON s.id  = ss.song_id
  JOIN instruments i ON i.id  = ss.instrument_id
  WHERE ss.status = 'learning'
    AND ss.deleted_at IS NULL
    AND s.deleted_at IS NULL
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

GRANT EXECUTE ON FUNCTION get_trending_songs(INT, TEXT, INT) TO authenticated;
