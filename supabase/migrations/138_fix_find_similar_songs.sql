-- Migration 138: Fix find_similar_songs
--
-- Two bugs fixed:
--
-- 1. Exact matches were excluded.
--    The original WHERE clause had:
--      AND NOT (LOWER(s.title) = LOWER(p_title) AND LOWER(s.artist) = LOWER(p_artist))
--    This silently suppressed the warning box when the user typed a song
--    that already exists verbatim — the most common duplicate case.
--    The warning box is useful even for exact matches (shows existing URLs,
--    lets the user confirm they mean the existing record). Removed.
--
-- 2. Soft-deleted songs were included.
--    There was no `AND s.deleted_at IS NULL` filter, so songs that have
--    been soft-deleted could appear as suggestions.

CREATE OR REPLACE FUNCTION find_similar_songs(
  p_title TEXT,
  p_artist TEXT,
  p_threshold FLOAT DEFAULT 0.3,
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  artist TEXT,
  similarity_score FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public', 'extensions'
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.title,
    s.artist,
    ((SIMILARITY(LOWER(s.title), LOWER(p_title)) + SIMILARITY(LOWER(s.artist), LOWER(p_artist))) / 2.0)::FLOAT AS similarity_score
  FROM songs s
  WHERE
    s.deleted_at IS NULL
    AND (
      SIMILARITY(LOWER(s.title), LOWER(p_title)) > p_threshold
      OR SIMILARITY(LOWER(s.artist), LOWER(p_artist)) > p_threshold
    )
  ORDER BY similarity_score DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION find_similar_songs(TEXT, TEXT, FLOAT, INTEGER) TO authenticated;
