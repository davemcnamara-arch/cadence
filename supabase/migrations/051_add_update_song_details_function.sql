-- Migration: Add function to update song title and artist
-- Allows teachers to correct spelling mistakes on songs

CREATE OR REPLACE FUNCTION update_song_details(
  p_song_id UUID,
  p_title TEXT,
  p_artist TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_user_role TEXT;
  v_result JSON;
BEGIN
  -- Get the current user
  v_current_user_id := auth.uid();

  -- Check if user is a teacher or admin
  SELECT role INTO v_user_role
  FROM users
  WHERE id = v_current_user_id;

  IF v_user_role NOT IN ('teacher', 'admin') THEN
    RAISE EXCEPTION 'Only teachers and admins can edit song details';
  END IF;

  -- Validate inputs
  IF p_title IS NULL OR trim(p_title) = '' THEN
    RAISE EXCEPTION 'Song title cannot be empty';
  END IF;

  IF p_artist IS NULL OR trim(p_artist) = '' THEN
    RAISE EXCEPTION 'Artist name cannot be empty';
  END IF;

  -- Check if song exists
  IF NOT EXISTS (SELECT 1 FROM songs WHERE id = p_song_id) THEN
    RAISE EXCEPTION 'Song not found';
  END IF;

  -- Update the song
  UPDATE songs
  SET title = trim(p_title),
      artist = trim(p_artist)
  WHERE id = p_song_id;

  -- Return result
  v_result := json_build_object(
    'song_id', p_song_id,
    'title', trim(p_title),
    'artist', trim(p_artist),
    'updated', true
  );

  RETURN v_result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION update_song_details(UUID, TEXT, TEXT) TO authenticated;
