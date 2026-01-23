-- Create functions to manage student songs on behalf of students
-- This bypasses RLS and validates teacher access internally

-- Function to update student song status (mark mastered/unmaster)
CREATE OR REPLACE FUNCTION update_student_song_status(
  p_student_song_id UUID,
  p_status TEXT,
  p_date_completed TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_student_id UUID;
  v_has_access BOOLEAN;
  v_result JSON;
BEGIN
  -- Get the current user
  v_current_user_id := auth.uid();

  -- Get the student ID from the student_song
  SELECT user_id INTO v_student_id
  FROM student_songs
  WHERE id = p_student_song_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student song not found';
  END IF;

  -- Check if current user is the student themselves OR a teacher with access
  SELECT (
    v_current_user_id = v_student_id
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = v_student_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- Update the song status
  UPDATE student_songs
  SET
    status = p_status,
    date_completed = p_date_completed
  WHERE id = p_student_song_id
  RETURNING json_build_object(
    'id', id,
    'user_id', user_id,
    'song_id', song_id,
    'instrument_id', instrument_id,
    'status', status,
    'date_completed', date_completed
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION update_student_song_status(UUID, TEXT, TIMESTAMP WITH TIME ZONE) TO authenticated;

-- Function to remove student song
CREATE OR REPLACE FUNCTION remove_student_song(
  p_student_song_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_student_id UUID;
  v_has_access BOOLEAN;
  v_result JSON;
BEGIN
  -- Get the current user
  v_current_user_id := auth.uid();

  -- Get the student ID from the student_song
  SELECT user_id INTO v_student_id
  FROM student_songs
  WHERE id = p_student_song_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student song not found';
  END IF;

  -- Check if current user is the student themselves OR a teacher with access
  SELECT (
    v_current_user_id = v_student_id
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = v_student_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- Store result before deleting
  SELECT json_build_object(
    'id', id,
    'user_id', user_id,
    'song_id', song_id
  ) INTO v_result
  FROM student_songs
  WHERE id = p_student_song_id;

  -- Delete the song
  DELETE FROM student_songs
  WHERE id = p_student_song_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION remove_student_song(UUID) TO authenticated;

-- Function to get student song details (for rating check)
CREATE OR REPLACE FUNCTION get_student_song_detail(
  p_student_song_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_student_id UUID;
  v_has_access BOOLEAN;
  v_result JSON;
BEGIN
  -- Get the current user
  v_current_user_id := auth.uid();

  -- Get the student ID from the student_song
  SELECT user_id INTO v_student_id
  FROM student_songs
  WHERE id = p_student_song_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student song not found';
  END IF;

  -- Check if current user is the student themselves OR a teacher with access
  SELECT (
    v_current_user_id = v_student_id
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = v_student_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- Get the student song with song details
  SELECT json_build_object(
    'id', ss.id,
    'user_id', ss.user_id,
    'song_id', ss.song_id,
    'instrument_id', ss.instrument_id,
    'status', ss.status,
    'date_started', ss.date_started,
    'date_completed', ss.date_completed,
    'songs', json_build_object(
      'id', s.id,
      'title', s.title,
      'artist', s.artist,
      'chords_url', s.chords_url,
      'tutorial_url', s.tutorial_url,
      'youtube_url', s.youtube_url,
      'suggested_level', s.suggested_level
    )
  ) INTO v_result
  FROM student_songs ss
  JOIN songs s ON ss.song_id = s.id
  WHERE ss.id = p_student_song_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_student_song_detail(UUID) TO authenticated;

-- Function to submit resource ratings on behalf of students
CREATE OR REPLACE FUNCTION submit_resource_ratings(
  p_student_song_id UUID,
  p_chords_rating INTEGER DEFAULT NULL,
  p_tutorial_rating INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_student_id UUID;
  v_has_access BOOLEAN;
  v_result JSON;
BEGIN
  -- Get the current user
  v_current_user_id := auth.uid();

  -- Get the student ID from the student_song
  SELECT user_id INTO v_student_id
  FROM student_songs
  WHERE id = p_student_song_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Student song not found';
  END IF;

  -- Check if current user is the student themselves OR a teacher with access
  SELECT (
    v_current_user_id = v_student_id
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = v_student_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- Insert the resource rating
  INSERT INTO resource_ratings (
    student_song_id,
    user_id,
    chords_rating,
    tutorial_rating
  )
  VALUES (
    p_student_song_id,
    v_student_id,
    p_chords_rating,
    p_tutorial_rating
  )
  RETURNING json_build_object(
    'id', id,
    'student_song_id', student_song_id,
    'user_id', user_id,
    'chords_rating', chords_rating,
    'tutorial_rating', tutorial_rating
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION submit_resource_ratings(UUID, INTEGER, INTEGER) TO authenticated;

