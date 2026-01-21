-- Database function to get students in a class
-- This bypasses RLS policies to avoid circular recursion issues
-- SECURITY: Requires authorization check - user must be teacher or class member

CREATE OR REPLACE FUNCTION public.get_class_students(
  p_class_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_is_authorized BOOLEAN;
  v_result JSON;
BEGIN
  -- Get the current user
  v_current_user_id := auth.uid();

  -- Check authorization: user must be either:
  -- 1. The teacher of this class, OR
  -- 2. A member of this class
  SELECT (
    EXISTS (
      SELECT 1
      FROM classes c
      WHERE c.id = p_class_id
        AND c.teacher_id = v_current_user_id
    )
    OR
    EXISTS (
      SELECT 1
      FROM class_members cm
      WHERE cm.class_id = p_class_id
        AND cm.user_id = v_current_user_id
    )
  ) INTO v_is_authorized;

  -- Deny access if not authorized
  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this class';
  END IF;

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
    -- Re-raise permission denied errors
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    -- Return empty array on other errors
    RETURN '[]'::json;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_class_students(UUID) TO authenticated;
