-- Fix get_trending_songs grouping so the score matches the song card count.
--
-- The previous version grouped by (song_id, student_instrument_name), producing
-- separate rows per instrument and a partial count per row. A song learned by
-- 5 students on guitar and 3 on bass would appear twice (5 and 3) rather than
-- once (8), mismatching the song card total.
--
-- Fix: group only by song_id. Join instruments twice —
--   si (student instrument) — used for instrument_filter only
--   pi (song's primary instrument) — returned as the display instrument name
-- The COUNT now aggregates all student_songs rows for the song regardless of
-- which instrument each student is learning it on.

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
  JOIN songs s        ON s.id   = ss.song_id
  JOIN instruments si ON si.id  = ss.instrument_id   -- student's chosen instrument (for filtering)
  JOIN instruments pi ON pi.id  = s.instrument_id    -- song's primary instrument (for display)
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
