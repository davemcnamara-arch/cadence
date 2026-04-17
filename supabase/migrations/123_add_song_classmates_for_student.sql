-- Allow students to see the names of school-mates who are learning/have mastered
-- a given song. "School" is derived from active class membership (class_members →
-- classes.school_id) rather than the school_students table, which can go stale
-- when students are removed from classes without an explicit school-level removal.

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
  -- The other student must be in a class at the same school as the current user
  INNER JOIN class_members their_cm ON their_cm.user_id = ss.user_id
  INNER JOIN classes their_class ON their_class.id = their_cm.class_id
  WHERE ss.song_id = p_song_id
    AND ss.deleted_at IS NULL
    AND ss.user_id != auth.uid()
    AND their_class.school_id IN (
      -- Schools the current user is actively enrolled in via class membership
      SELECT c.school_id
      FROM class_members cm
      INNER JOIN classes c ON c.id = cm.class_id
      WHERE cm.user_id = auth.uid()
        AND c.school_id IS NOT NULL
    )
  ORDER BY ss.user_id, ss.date_started DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_song_classmates_for_student(UUID) TO authenticated;
