-- Create a function for teachers to see which of their students are learning or have mastered a specific song
-- Returns student name, status (learning/mastered), instrument, class info, and dates

CREATE OR REPLACE FUNCTION get_song_students_for_teacher(
  p_song_id UUID,
  p_include_archived BOOLEAN DEFAULT false
)
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  status TEXT,
  instrument_id UUID,
  instrument_name TEXT,
  instrument_icon TEXT,
  date_started TIMESTAMPTZ,
  date_completed TIMESTAMPTZ,
  class_name TEXT,
  class_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only allow teachers and admins
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin')) THEN
    RAISE EXCEPTION 'Permission denied: must be a teacher or admin';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (ss.user_id, ss.instrument_id)
    ss.user_id,
    u.name,
    ss.status,
    ss.instrument_id,
    i.name AS instrument_name,
    i.icon AS instrument_icon,
    ss.date_started,
    ss.date_completed,
    c.name AS class_name,
    c.id AS class_id
  FROM student_songs ss
  INNER JOIN users u ON ss.user_id = u.id
  INNER JOIN instruments i ON ss.instrument_id = i.id
  INNER JOIN class_members cm ON ss.user_id = cm.user_id
  INNER JOIN classes c ON cm.class_id = c.id
  WHERE ss.song_id = p_song_id
    AND c.teacher_id = auth.uid()
    AND (p_include_archived = true OR c.archived IS NOT TRUE)
  ORDER BY ss.user_id, ss.instrument_id, ss.date_started DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_song_students_for_teacher(UUID, BOOLEAN) TO authenticated;

-- Create a function to get student counts per song for all songs tracked by a teacher's students
-- Used to show badges on song cards in the Song Library view

CREATE OR REPLACE FUNCTION get_teacher_student_song_counts(
  p_include_archived BOOLEAN DEFAULT false
)
RETURNS TABLE (
  song_id UUID,
  learning_count BIGINT,
  mastered_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only allow teachers and admins
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin')) THEN
    RAISE EXCEPTION 'Permission denied: must be a teacher or admin';
  END IF;

  RETURN QUERY
  SELECT
    ss.song_id,
    COUNT(*) FILTER (WHERE ss.status = 'learning') AS learning_count,
    COUNT(*) FILTER (WHERE ss.status = 'mastered') AS mastered_count
  FROM student_songs ss
  INNER JOIN class_members cm ON ss.user_id = cm.user_id
  INNER JOIN classes c ON cm.class_id = c.id
  WHERE c.teacher_id = auth.uid()
    AND (p_include_archived = true OR c.archived IS NOT TRUE)
  GROUP BY ss.song_id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_teacher_student_song_counts(BOOLEAN) TO authenticated;
