-- Create a function to update song ratings
-- This bypasses RLS and validates teacher access internally

CREATE OR REPLACE FUNCTION update_song_rating(
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
  -- Get the current user
  v_current_user_id := auth.uid();

  -- Get the student_id (user_id) from the rating
  SELECT user_id INTO v_student_id
  FROM song_ratings
  WHERE id = p_rating_id;

  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Rating not found';
  END IF;

  -- Check if current user is authorized to update this rating
  -- Either: (1) they are the student themselves, OR
  --         (2) they are a teacher with the student in their class
  SELECT (
    v_current_user_id = v_student_id
    OR
    EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = v_student_id
    )
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to update this rating';
  END IF;

  -- Update the rating
  UPDATE song_ratings
  SET assessed_level = p_assessed_level
  WHERE id = p_rating_id;

  -- Return result
  v_result := json_build_object(
    'rating_id', p_rating_id,
    'assessed_level', p_assessed_level,
    'updated', true
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION update_song_rating(UUID, INTEGER) TO authenticated;
