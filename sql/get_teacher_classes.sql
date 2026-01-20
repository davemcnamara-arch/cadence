-- Database function to get teacher's classes with student counts
-- This bypasses RLS policies to get accurate student counts

CREATE OR REPLACE FUNCTION public.get_teacher_classes(
  p_teacher_id UUID,
  p_include_archived BOOLEAN DEFAULT false
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSON;
BEGIN
  -- Get classes for the teacher with student counts
  -- Optionally include archived classes based on parameter
  SELECT json_agg(
    json_build_object(
      'id', c.id,
      'name', c.name,
      'year_level', c.year_level,
      'class_code', c.class_code,
      'teacher_id', c.teacher_id,
      'created_at', c.created_at,
      'archived', c.archived,
      'student_count', (
        SELECT COUNT(*)
        FROM class_members cm
        WHERE cm.class_id = c.id
      )
    )
    ORDER BY c.created_at DESC
  )
  INTO v_result
  FROM classes c
  WHERE c.teacher_id = p_teacher_id
    AND (p_include_archived = true OR c.archived = false);

  -- Return the result (will be null if no classes)
  RETURN COALESCE(v_result, '[]'::json);

EXCEPTION
  WHEN OTHERS THEN
    -- Return empty array on error
    RETURN '[]'::json;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_teacher_classes(UUID, BOOLEAN) TO authenticated;
