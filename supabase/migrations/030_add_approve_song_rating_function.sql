-- Create RPC function to approve/review song ratings
-- This bypasses RLS policies which can cause timeouts on complex queries

CREATE OR REPLACE FUNCTION approve_song_rating(
  p_rating_id UUID,
  p_assessed_level INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_is_authorized BOOLEAN;
  v_student_id UUID;
  v_result JSON;
BEGIN
  -- Get the current user (teacher)
  v_current_user_id := auth.uid();

  -- Get the student_id from the rating
  SELECT user_id INTO v_student_id
  FROM song_ratings
  WHERE id = p_rating_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Rating not found';
  END IF;

  -- Check if current user is authorized to approve this rating
  -- (must be the teacher of the student who created the rating)
  SELECT EXISTS (
    SELECT 1
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = v_current_user_id
      AND cm.user_id = v_student_id
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to approve this rating';
  END IF;

  -- Update the rating
  UPDATE song_ratings
  SET assessed_level = p_assessed_level,
      teacher_reviewed = true
  WHERE id = p_rating_id;

  -- Return success result
  v_result := json_build_object(
    'success', true,
    'rating_id', p_rating_id
  );

  RETURN v_result;
END;
$$;
