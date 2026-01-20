-- Create RPC function to get class timeline data
-- This bypasses RLS issues with complex joins

CREATE OR REPLACE FUNCTION get_class_timeline(p_class_id UUID)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  song_id UUID,
  instrument_id UUID,
  status TEXT,
  date_started TIMESTAMP WITH TIME ZONE,
  date_completed TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  student_name TEXT,
  song_title TEXT,
  song_artist TEXT,
  instrument_icon TEXT,
  instrument_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_id UUID;
  v_is_teacher BOOLEAN;
BEGIN
  -- Get the current user
  v_teacher_id := auth.uid();

  -- Check if current user is the teacher of this class
  SELECT EXISTS (
    SELECT 1
    FROM classes c
    WHERE c.id = p_class_id
      AND c.teacher_id = v_teacher_id
  ) INTO v_is_teacher;

  -- If not the teacher, deny access
  IF NOT v_is_teacher THEN
    RAISE EXCEPTION 'Permission denied: You are not the teacher of this class';
  END IF;

  -- Return the timeline data
  RETURN QUERY
  SELECT
    ss.id,
    ss.user_id,
    ss.song_id,
    ss.instrument_id,
    ss.status,
    ss.date_started,
    ss.date_completed,
    ss.notes,
    u.name as student_name,
    s.title as song_title,
    s.artist as song_artist,
    i.icon as instrument_icon,
    i.name as instrument_name
  FROM student_songs ss
  JOIN class_members cm ON ss.user_id = cm.user_id
  JOIN users u ON ss.user_id = u.id
  JOIN songs s ON ss.song_id = s.id
  JOIN instruments i ON ss.instrument_id = i.id
  WHERE cm.class_id = p_class_id
  ORDER BY ss.date_started DESC
  LIMIT 20;
END;
$$;

GRANT EXECUTE ON FUNCTION get_class_timeline(UUID) TO authenticated;
