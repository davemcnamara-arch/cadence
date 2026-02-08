-- Create a function to search all students across a teacher's classes
-- Returns student info along with class names for display in search results

CREATE OR REPLACE FUNCTION search_teacher_students()
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  email TEXT,
  class_id UUID,
  class_name TEXT,
  joined_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.name,
    u.email,
    c.id AS class_id,
    c.name AS class_name,
    cm.joined_at
  FROM users u
  INNER JOIN class_members cm ON u.id = cm.user_id
  INNER JOIN classes c ON cm.class_id = c.id
  WHERE c.teacher_id = auth.uid()
    AND c.archived IS NOT TRUE
  ORDER BY u.name, c.name;
END;
$$;

GRANT EXECUTE ON FUNCTION search_teacher_students() TO authenticated;
