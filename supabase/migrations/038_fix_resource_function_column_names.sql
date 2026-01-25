-- Fix ambiguous column references in get_song_resources and get_song_tutorials functions

-- Drop and recreate get_song_resources with unique output column names
DROP FUNCTION IF EXISTS get_song_resources(UUID);

CREATE OR REPLACE FUNCTION get_song_resources(
  p_song_id UUID
)
RETURNS TABLE (
  resource_id UUID,
  resource_title TEXT,
  resource_description TEXT,
  resource_file_url TEXT,
  resource_file_type TEXT,
  resource_status TEXT,
  contributor_name TEXT,
  resource_created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_teacher BOOLEAN;
BEGIN
  -- Check if current user is a teacher
  SELECT role IN ('teacher', 'admin') INTO v_is_teacher
  FROM users WHERE users.id = auth.uid();

  RETURN QUERY
  SELECT
    sr.id AS resource_id,
    sr.title AS resource_title,
    sr.description AS resource_description,
    sr.file_url AS resource_file_url,
    sr.file_type AS resource_file_type,
    sr.status AS resource_status,
    COALESCE(u.name, 'Student')::TEXT AS contributor_name,
    sr.created_at AS resource_created_at
  FROM student_resources sr
  LEFT JOIN users u ON sr.user_id = u.id
  WHERE sr.song_id = p_song_id
    AND (sr.status = 'approved' OR v_is_teacher OR sr.user_id = auth.uid())
  ORDER BY sr.created_at DESC;
END;
$$;

-- Drop and recreate get_song_tutorials with unique output column names
DROP FUNCTION IF EXISTS get_song_tutorials(UUID);

CREATE OR REPLACE FUNCTION get_song_tutorials(
  p_song_id UUID
)
RETURNS TABLE (
  tutorial_id UUID,
  tutorial_url TEXT,
  tutorial_title TEXT,
  tutorial_status TEXT,
  contributor_name TEXT,
  tutorial_created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_is_teacher BOOLEAN;
BEGIN
  -- Check if current user is a teacher
  SELECT role IN ('teacher', 'admin') INTO v_is_teacher
  FROM users WHERE users.id = auth.uid();

  RETURN QUERY
  SELECT
    st.id AS tutorial_id,
    st.url AS tutorial_url,
    st.title AS tutorial_title,
    st.status AS tutorial_status,
    COALESCE(u.name, 'Teacher')::TEXT AS contributor_name,
    st.created_at AS tutorial_created_at
  FROM song_tutorials st
  LEFT JOIN users u ON st.submitted_by_user_id = u.id
  WHERE st.song_id = p_song_id
    AND (st.status = 'approved' OR v_is_teacher OR st.submitted_by_user_id = auth.uid())
  ORDER BY st.created_at ASC;
END;
$$;
