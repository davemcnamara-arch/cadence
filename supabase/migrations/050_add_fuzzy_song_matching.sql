-- Enable pg_trgm extension for fuzzy text matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create function to find similar songs based on title and artist
-- Uses trigram similarity for fuzzy matching
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
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id,
    s.title,
    s.artist,
    -- Combined similarity: average of title and artist similarity
    ((SIMILARITY(LOWER(s.title), LOWER(p_title)) + SIMILARITY(LOWER(s.artist), LOWER(p_artist))) / 2.0)::FLOAT AS similarity_score
  FROM songs s
  WHERE
    -- Filter: at least one of title or artist should be somewhat similar
    (SIMILARITY(LOWER(s.title), LOWER(p_title)) > p_threshold
     OR SIMILARITY(LOWER(s.artist), LOWER(p_artist)) > p_threshold)
    -- Exclude exact matches (those will be handled by existing logic)
    AND NOT (LOWER(s.title) = LOWER(p_title) AND LOWER(s.artist) = LOWER(p_artist))
  ORDER BY similarity_score DESC
  LIMIT p_limit;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION find_similar_songs(TEXT, TEXT, FLOAT, INTEGER) TO authenticated;

-- Add comment for documentation
COMMENT ON FUNCTION find_similar_songs IS 'Finds songs with similar title/artist using trigram similarity. Used to detect potential duplicates during song entry.';
