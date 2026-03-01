-- RPC function: get_trending_songs
-- Returns songs ordered by how many students started learning them
-- in the last days_back days, optionally filtered by instrument name.

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
  JOIN instruments i   ON i.id    = s.instrument_id
  JOIN student_songs ss ON ss.song_id = s.id
  WHERE ss.date_started >= NOW() - (days_back || ' days')::INTERVAL
    AND (instrument_filter IS NULL OR i.name ILIKE instrument_filter)
  GROUP BY s.id, s.title, s.artist, i.name
  ORDER BY trending_score DESC
  LIMIT limit_count;
END;
$$;

GRANT EXECUTE ON FUNCTION get_trending_songs(INT, INT, TEXT) TO authenticated;
