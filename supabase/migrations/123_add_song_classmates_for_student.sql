-- Allow students to see the names of classmates who are learning/have mastered
-- a given song. "Classmates" means any student sharing at least one class with
-- the current user.

CREATE OR REPLACE FUNCTION get_song_classmates_for_student(
  p_song_id UUID
)
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (ss.user_id)
    ss.user_id,
    u.name,
    ss.status
  FROM student_songs ss
  INNER JOIN users u ON ss.user_id = u.id
  -- The classmate must share at least one class with the current user
  INNER JOIN class_members their_cm ON their_cm.user_id = ss.user_id
  INNER JOIN class_members my_cm
    ON my_cm.class_id = their_cm.class_id
    AND my_cm.user_id = auth.uid()
  WHERE ss.song_id = p_song_id
    AND ss.deleted_at IS NULL
    AND ss.user_id != auth.uid()
  ORDER BY ss.user_id, ss.date_started DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_song_classmates_for_student(UUID) TO authenticated;
