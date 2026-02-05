-- Migration: Move pg_trgm extension from public to extensions schema
-- This addresses the security warning about extensions in the public schema

-- Create the extensions schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS extensions;

-- Grant usage on the extensions schema to authenticated users
GRANT USAGE ON SCHEMA extensions TO authenticated;
GRANT USAGE ON SCHEMA extensions TO anon;
GRANT USAGE ON SCHEMA extensions TO service_role;

-- Drop and recreate the extension in the extensions schema
DROP EXTENSION IF EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

-- Update find_similar_songs function to include extensions schema in search_path
-- so it can find the SIMILARITY function from pg_trgm
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

-- Ensure execute permission is granted
GRANT EXECUTE ON FUNCTION find_similar_songs(TEXT, TEXT, FLOAT, INTEGER) TO authenticated;
