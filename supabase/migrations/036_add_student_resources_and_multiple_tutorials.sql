-- Migration: Add student resources (file uploads) and multiple tutorial URLs
-- This enables:
-- 1. Students to share helpful resources (drawings, notes, PDFs) for songs
-- 2. Multiple tutorial video URLs per song instead of just one

-- ==============================================
-- STUDENT RESOURCES TABLE (for file uploads)
-- ==============================================

CREATE TABLE student_resources (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  song_id UUID REFERENCES songs(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  description TEXT,
  file_url TEXT NOT NULL,
  file_type TEXT NOT NULL CHECK (file_type IN ('image', 'pdf', 'link')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for faster queries
CREATE INDEX idx_student_resources_song_id ON student_resources(song_id);
CREATE INDEX idx_student_resources_status ON student_resources(status);
CREATE INDEX idx_student_resources_user_id ON student_resources(user_id);

-- Enable RLS
ALTER TABLE student_resources ENABLE ROW LEVEL SECURITY;

-- Students can submit resources
CREATE POLICY "Students can submit resources" ON student_resources
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role = 'student'
    )
  );

-- Everyone can view approved resources, users can view their own pending
CREATE POLICY "Users can view approved resources or their own" ON student_resources
  FOR SELECT
  USING (
    status = 'approved'
    OR user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('teacher', 'admin')
    )
  );

-- Teachers can review resources
CREATE POLICY "Teachers can review resources" ON student_resources
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('teacher', 'admin')
    )
  );

-- Teachers can delete resources
CREATE POLICY "Teachers can delete resources" ON student_resources
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('teacher', 'admin')
    )
  );

-- ==============================================
-- SONG TUTORIALS TABLE (for multiple tutorial URLs)
-- ==============================================

CREATE TABLE song_tutorials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  song_id UUID REFERENCES songs(id) ON DELETE CASCADE NOT NULL,
  url TEXT NOT NULL,
  title TEXT,
  submitted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_song_tutorials_song_id ON song_tutorials(song_id);
CREATE INDEX idx_song_tutorials_status ON song_tutorials(status);

-- Enable RLS
ALTER TABLE song_tutorials ENABLE ROW LEVEL SECURITY;

-- Anyone can view approved tutorials
CREATE POLICY "Anyone can view approved tutorials" ON song_tutorials
  FOR SELECT
  USING (
    status = 'approved'
    OR submitted_by_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('teacher', 'admin')
    )
  );

-- Students can submit tutorials for approval
CREATE POLICY "Students can submit tutorials" ON song_tutorials
  FOR INSERT
  WITH CHECK (
    auth.uid() = submitted_by_user_id
  );

-- Teachers can review tutorials
CREATE POLICY "Teachers can review tutorials" ON song_tutorials
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('teacher', 'admin')
    )
  );

-- Teachers can delete tutorials
CREATE POLICY "Teachers can delete tutorials" ON song_tutorials
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('teacher', 'admin')
    )
  );

-- ==============================================
-- MIGRATE EXISTING TUTORIAL URLs
-- ==============================================

-- Move existing tutorial_url values to song_tutorials table (as approved)
INSERT INTO song_tutorials (song_id, url, title, status, created_at)
SELECT id, tutorial_url, 'Original Tutorial', 'approved', NOW()
FROM songs
WHERE tutorial_url IS NOT NULL AND tutorial_url != '';

-- ==============================================
-- FUNCTIONS FOR MANAGING RESOURCES
-- ==============================================

-- Function to approve a student resource
CREATE OR REPLACE FUNCTION approve_student_resource(
  p_resource_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE student_resources
  SET status = 'approved',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = p_resource_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource not found or already processed';
  END IF;
END;
$$;

-- Function to reject a student resource
CREATE OR REPLACE FUNCTION reject_student_resource(
  p_resource_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE student_resources
  SET status = 'rejected',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = p_resource_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Resource not found or already processed';
  END IF;
END;
$$;

-- Function to approve a tutorial
CREATE OR REPLACE FUNCTION approve_song_tutorial(
  p_tutorial_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE song_tutorials
  SET status = 'approved',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = p_tutorial_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tutorial not found or already processed';
  END IF;
END;
$$;

-- Function to reject a tutorial
CREATE OR REPLACE FUNCTION reject_song_tutorial(
  p_tutorial_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE song_tutorials
  SET status = 'rejected',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = p_tutorial_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tutorial not found or already processed';
  END IF;
END;
$$;

-- Function to get all resources for a song (approved only for students, all for teachers)
CREATE OR REPLACE FUNCTION get_song_resources(
  p_song_id UUID
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  file_url TEXT,
  file_type TEXT,
  status TEXT,
  contributor_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
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
    COALESCE(u.name, 'Student') as contributor_name,
    sr.created_at
  FROM student_resources sr
  LEFT JOIN users u ON sr.user_id = u.id
  WHERE sr.song_id = p_song_id
    AND (sr.status = 'approved' OR v_is_teacher OR sr.user_id = auth.uid())
  ORDER BY sr.created_at DESC;
END;
$$;

-- Function to get all tutorials for a song
CREATE OR REPLACE FUNCTION get_song_tutorials(
  p_song_id UUID
)
RETURNS TABLE (
  id UUID,
  url TEXT,
  title TEXT,
  status TEXT,
  contributor_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
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
    COALESCE(u.name, 'Teacher') as contributor_name,
    st.created_at
  FROM song_tutorials st
  LEFT JOIN users u ON st.submitted_by_user_id = u.id
  WHERE st.song_id = p_song_id
    AND (st.status = 'approved' OR v_is_teacher OR st.submitted_by_user_id = auth.uid())
  ORDER BY st.created_at ASC;
END;
$$;

-- ==============================================
-- STORAGE BUCKET FOR STUDENT RESOURCES
-- ==============================================

-- Note: Storage bucket needs to be created via Supabase dashboard or CLI:
-- supabase storage bucket create student-resources --public
-- The bucket should allow uploads of images and PDFs up to 5MB
