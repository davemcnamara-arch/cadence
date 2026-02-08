-- Create a function to search all students across a teacher's classes
-- Returns active students and pending enrollments with class names

CREATE OR REPLACE FUNCTION search_teacher_students()
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  email TEXT,
  class_id UUID,
  class_name TEXT,
  joined_at TIMESTAMPTZ,
  is_pending BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Active students
  RETURN QUERY
  SELECT
    u.id AS user_id,
    u.name,
    u.email,
    c.id AS class_id,
    c.name AS class_name,
    cm.joined_at,
    FALSE AS is_pending
  FROM users u
  INNER JOIN class_members cm ON u.id = cm.user_id
  INNER JOIN classes c ON cm.class_id = c.id
  WHERE c.teacher_id = auth.uid()
    AND c.archived IS NOT TRUE;

  -- Pending enrollments (no user_id yet since they haven't logged in)
  RETURN QUERY
  SELECT
    NULL::UUID AS user_id,
    SPLIT_PART(pe.email, '@', 1) AS name,
    pe.email,
    c.id AS class_id,
    c.name AS class_name,
    pe.created_at AS joined_at,
    TRUE AS is_pending
  FROM pending_enrollments pe
  INNER JOIN classes c ON pe.class_id = c.id
  WHERE c.teacher_id = auth.uid()
    AND c.archived IS NOT TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION search_teacher_students() TO authenticated;
