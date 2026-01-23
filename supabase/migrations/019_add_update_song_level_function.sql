-- Migration: Add function to update song suggested level
-- This bypasses RLS policies to avoid infinite recursion

CREATE OR REPLACE FUNCTION update_song_suggested_level(
  p_song_id UUID,
  p_level INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only teachers and admins can update song levels
  IF NOT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role IN ('teacher', 'admin')
  ) THEN
    RAISE EXCEPTION 'Only teachers and admins can update song levels';
  END IF;

  -- Update the song's suggested level
  UPDATE songs
  SET suggested_level = p_level,
      updated_at = NOW()
  WHERE id = p_song_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_song_suggested_level(UUID, INTEGER) TO authenticated;
