-- Create a function to get all students from all classes taught by the current user
-- This bypasses RLS and is needed for the submissions tab

CREATE OR REPLACE FUNCTION get_all_teacher_students()
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT
    u.id as user_id,
    u.name,
    u.email
  FROM users u
  INNER JOIN class_members cm ON u.id = cm.user_id
  INNER JOIN classes c ON cm.class_id = c.id
  WHERE c.teacher_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_teacher_students() TO authenticated;
