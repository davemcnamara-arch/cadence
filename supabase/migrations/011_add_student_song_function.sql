-- Create a function to add songs on behalf of students
-- This bypasses RLS and validates teacher access internally

CREATE OR REPLACE FUNCTION add_student_song(
  p_student_id UUID,
  p_song_id UUID,
  p_instrument_id UUID,
  p_status TEXT DEFAULT 'learning'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID;
  v_is_teacher BOOLEAN;
  v_result JSON;
BEGIN
  -- Get the current user (teacher)
  v_teacher_id := auth.uid();

  -- Check if current user is a teacher and the student is in their class
  SELECT EXISTS (
    SELECT 1
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = v_teacher_id
      AND cm.user_id = p_student_id
  ) INTO v_is_teacher;

  -- If not a teacher with access, check if it's the student themselves
  IF NOT v_is_teacher AND v_teacher_id != p_student_id THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- Check if song already exists
  IF EXISTS (
    SELECT 1 FROM student_songs
    WHERE user_id = p_student_id
      AND song_id = p_song_id
      AND instrument_id = p_instrument_id
  ) THEN
    RAISE EXCEPTION 'Student is already tracking this song';
  END IF;

  -- Insert the song
  INSERT INTO student_songs (user_id, song_id, instrument_id, status)
  VALUES (p_student_id, p_song_id, p_instrument_id, p_status)
  RETURNING json_build_object(
    'id', id,
    'user_id', user_id,
    'song_id', song_id,
    'instrument_id', instrument_id,
    'status', status,
    'date_started', date_started
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION add_student_song(UUID, UUID, UUID, TEXT) TO authenticated;
