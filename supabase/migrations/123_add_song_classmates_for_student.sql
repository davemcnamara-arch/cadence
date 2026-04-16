-- Allow students to see the names of school-mates who are learning/have mastered
-- a given song. "School" means any student in any class taught by the same
-- teacher(s) as the current user's classes.

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
  -- Find any class the other student is in
  INNER JOIN class_members their_cm ON their_cm.user_id = ss.user_id
  INNER JOIN classes their_class ON their_class.id = their_cm.class_id
  WHERE ss.song_id = p_song_id
    AND ss.deleted_at IS NULL
    AND ss.user_id != auth.uid()
    -- Their class must be taught by a teacher who also teaches the current user
    AND their_class.teacher_id IN (
      SELECT c.teacher_id
      FROM class_members cm
      INNER JOIN classes c ON c.id = cm.class_id
      WHERE cm.user_id = auth.uid()
    )
  ORDER BY ss.user_id, ss.date_started DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_song_classmates_for_student(UUID) TO authenticated;
