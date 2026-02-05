-- Migration: Add instrument_id to song_tutorials and student_resources
-- This allows tutorials and resources to be instrument-specific
-- NULL instrument_id means the tutorial/resource applies to all instruments (universal)

-- ==============================================
-- ADD instrument_id TO song_tutorials
-- ==============================================

ALTER TABLE song_tutorials
ADD COLUMN instrument_id UUID REFERENCES instruments(id) ON DELETE SET NULL;

-- Index for filtering by instrument
CREATE INDEX idx_song_tutorials_instrument_id ON song_tutorials(instrument_id);

-- ==============================================
-- ADD instrument_id TO student_resources
-- ==============================================

ALTER TABLE student_resources
ADD COLUMN instrument_id UUID REFERENCES instruments(id) ON DELETE SET NULL;

-- Index for filtering by instrument
CREATE INDEX idx_student_resources_instrument_id ON student_resources(instrument_id);

-- ==============================================
-- UPDATE get_song_tutorials FUNCTION
-- ==============================================

-- Drop and recreate to add instrument filtering
DROP FUNCTION IF EXISTS get_song_tutorials(UUID);

CREATE OR REPLACE FUNCTION get_song_tutorials(
  p_song_id UUID,
  p_instrument_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  url TEXT,
  title TEXT,
  status TEXT,
  instrument_id UUID,
  instrument_name TEXT,
  contributor_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_is_teacher BOOLEAN;
BEGIN
  -- Check if current user is a teacher
  SELECT role IN ('teacher', 'admin') INTO v_is_teacher
  FROM users WHERE id = auth.uid();

  RETURN QUERY
  SELECT
    st.id,
    st.url,
    st.title,
    st.status,
    st.instrument_id,
    i.name as instrument_name,
    COALESCE(u.name, 'Teacher') as contributor_name,
    st.created_at
  FROM song_tutorials st
  LEFT JOIN users u ON st.submitted_by_user_id = u.id
  LEFT JOIN instruments i ON st.instrument_id = i.id
  WHERE st.song_id = p_song_id
    AND (st.status = 'approved' OR v_is_teacher OR st.submitted_by_user_id = auth.uid())
    -- Filter by instrument: show matching instrument OR universal (NULL instrument_id)
    AND (p_instrument_id IS NULL OR st.instrument_id IS NULL OR st.instrument_id = p_instrument_id)
  ORDER BY st.created_at ASC;
END;
$$;

-- ==============================================
-- UPDATE get_song_resources FUNCTION
-- ==============================================

-- Drop and recreate to add instrument filtering
DROP FUNCTION IF EXISTS get_song_resources(UUID);

CREATE OR REPLACE FUNCTION get_song_resources(
  p_song_id UUID,
  p_instrument_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  file_url TEXT,
  file_type TEXT,
  status TEXT,
  instrument_id UUID,
  instrument_name TEXT,
  contributor_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_is_teacher BOOLEAN;
BEGIN
  -- Check if current user is a teacher
  SELECT role IN ('teacher', 'admin') INTO v_is_teacher
  FROM users WHERE id = auth.uid();

  RETURN QUERY
  SELECT
    sr.id,
    sr.title,
    sr.description,
    sr.file_url,
    sr.file_type,
    sr.status,
    sr.instrument_id,
    i.name as instrument_name,
    COALESCE(u.name, 'Student') as contributor_name,
    sr.created_at
  FROM student_resources sr
  LEFT JOIN users u ON sr.user_id = u.id
  LEFT JOIN instruments i ON sr.instrument_id = i.id
  WHERE sr.song_id = p_song_id
    AND (sr.status = 'approved' OR v_is_teacher OR sr.user_id = auth.uid())
    -- Filter by instrument: show matching instrument OR universal (NULL instrument_id)
    AND (p_instrument_id IS NULL OR sr.instrument_id IS NULL OR sr.instrument_id = p_instrument_id)
  ORDER BY sr.created_at DESC;
END;
$$;
