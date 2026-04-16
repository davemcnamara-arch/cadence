-- Allow students to see the names of school-mates who are learning/have mastered
-- a given song. "School" is determined via the school_students table, so all
-- students enrolled at the same school(s) as the current user are included,
-- regardless of which teacher or class they belong to.

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
  -- The other student must be at the same school as the current user
  INNER JOIN school_students their_school ON their_school.user_id = ss.user_id
  WHERE ss.song_id = p_song_id
    AND ss.deleted_at IS NULL
    AND ss.user_id != auth.uid()
    AND their_school.school_id IN (
      SELECT school_id FROM school_students WHERE user_id = auth.uid()
    )
  ORDER BY ss.user_id, ss.date_started DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_song_classmates_for_student(UUID) TO authenticated;
