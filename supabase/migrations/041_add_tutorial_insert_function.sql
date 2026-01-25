-- Create a SECURITY DEFINER function to insert tutorials, bypassing RLS
CREATE OR REPLACE FUNCTION add_song_tutorial(
  p_song_id UUID,
  p_url TEXT,
  p_title TEXT DEFAULT NULL,
  p_status TEXT DEFAULT 'pending'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO song_tutorials (song_id, url, title, submitted_by_user_id, status)
  VALUES (p_song_id, p_url, p_title, auth.uid(), p_status)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- Create a similar function for student resources
CREATE OR REPLACE FUNCTION add_student_resource(
  p_song_id UUID,
  p_title TEXT,
  p_file_url TEXT,
  p_file_type TEXT,
  p_description TEXT DEFAULT NULL,
  p_status TEXT DEFAULT 'pending'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO student_resources (song_id, user_id, title, description, file_url, file_type, status)
  VALUES (p_song_id, auth.uid(), p_title, p_description, p_file_url, p_file_type, p_status)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
