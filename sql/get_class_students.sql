-- Database function to get students in a class
-- This bypasses RLS policies to avoid circular recursion issues

CREATE OR REPLACE FUNCTION public.get_class_students(
  p_class_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSON;
BEGIN
  -- Get all students in the class with their progress
  SELECT json_agg(
    json_build_object(
      'id', cm.id,
      'class_id', cm.class_id,
      'user_id', cm.user_id,
      'joined_at', cm.joined_at,
      'users', json_build_object(
        'id', u.id,
        'name', u.name,
        'email', u.email
      ),
      'student_progress', (
        SELECT json_agg(
          json_build_object(
            'instrument_id', sp.instrument_id,
            'current_level', sp.current_level,
            'current_branch', sp.current_branch
          )
        )
        FROM student_progress sp
        WHERE sp.user_id = u.id
      )
    )
    ORDER BY cm.joined_at ASC
  )
  INTO v_result
  FROM class_members cm
  JOIN users u ON u.id = cm.user_id
  WHERE cm.class_id = p_class_id;

  -- Return the result (will be null if no students)
  RETURN COALESCE(v_result, '[]'::json);

EXCEPTION
  WHEN OTHERS THEN
    -- Return empty array on error
    RETURN '[]'::json;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_class_students(UUID) TO authenticated;
