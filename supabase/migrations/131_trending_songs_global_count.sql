-- Make get_trending_songs count students across all schools, not just the
-- calling user's school.
--
-- SECURITY DEFINER alone isn't sufficient in Supabase to bypass RLS when the
-- function owner lacks the BYPASSRLS privilege. The student_songs RLS policies
-- restrict visibility to the caller's own rows and classmates, which scopes the
-- count to a single school. Setting row_security = off inside the function
-- ensures the aggregate counts every student globally, regardless of school.
-- No student-identifying information is returned — only song metadata and an
-- anonymous aggregate count.

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
  SET LOCAL row_security = off;

  RETURN QUERY
  SELECT
    s.id                 AS song_id,
    s.title              AS title,
    s.artist             AS artist,
    pi.name              AS instrument,
    COUNT(ss.id)::BIGINT AS trending_score
  FROM student_songs ss
  JOIN songs s         ON s.id   = ss.song_id
  JOIN instruments si  ON si.id  = ss.instrument_id
  LEFT JOIN instruments pi ON pi.id = s.instrument_id
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
