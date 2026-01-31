-- Recreate the function to return void instead of UUID
-- The return value might be causing RLS issues when serializing

DROP FUNCTION IF EXISTS add_song_tutorial(UUID, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION add_song_tutorial(
  p_song_id UUID,
  p_url TEXT,
  p_title TEXT DEFAULT NULL,
  p_status TEXT DEFAULT 'pending'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO song_tutorials (song_id, url, title, submitted_by_user_id, status)
  VALUES (p_song_id, p_url, p_title, auth.uid(), p_status);
END;
$$;
