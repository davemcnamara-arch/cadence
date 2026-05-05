-- Find other students' custom instrument names that are similar to the one being entered.
-- Allows students to reuse an existing canonical name so song suggestions work correctly.
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
    AND NOT (LOWER(sp.custom_instrument_name) = LOWER(p_name))
    AND (p_student_id IS NULL OR sp.user_id != p_student_id)
  GROUP BY LOWER(sp.custom_instrument_name)
  ORDER BY similarity_score DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION find_similar_instruments(TEXT, UUID, FLOAT, INTEGER) TO authenticated;

COMMENT ON FUNCTION find_similar_instruments IS 'Finds custom instrument names used by other students that are similar to the input. Used to surface duplicate instrument entries so song suggestions work correctly.';
