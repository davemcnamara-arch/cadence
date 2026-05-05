-- Run this in the Supabase SQL editor (dashboard → SQL Editor → New query).
-- Creates the find_similar_instruments function used to suggest canonical
-- instrument names when a student types a custom name.

CREATE OR REPLACE FUNCTION find_similar_instruments(
  p_name TEXT,
  p_student_id UUID DEFAULT NULL,
  p_threshold FLOAT DEFAULT 0.3,
  p_limit INTEGER DEFAULT 5
)
RETURNS TABLE (
  custom_name TEXT,
  similarity_score FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    MIN(sp.custom_instrument_name) AS custom_name,
    SIMILARITY(LOWER(MIN(sp.custom_instrument_name)), LOWER(p_name))::FLOAT AS similarity_score
  FROM student_progress sp
  WHERE
    sp.custom_instrument_name IS NOT NULL
    AND SIMILARITY(LOWER(sp.custom_instrument_name), LOWER(p_name)) > p_threshold
    AND (p_student_id IS NULL OR sp.user_id != p_student_id)
  GROUP BY LOWER(sp.custom_instrument_name)
  ORDER BY similarity_score DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION find_similar_instruments(TEXT, UUID, FLOAT, INTEGER) TO authenticated;
