-- Fix RLS policy recursion in song_tutorials and student_resources SELECT policies
-- The subqueries checking users table cause infinite recursion

-- Create helper function to check if user is teacher (avoids recursion)
CREATE OR REPLACE FUNCTION is_teacher()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
    AND role IN ('teacher', 'admin')
  )
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Fix song_tutorials SELECT policy
DROP POLICY IF EXISTS "Anyone can view approved tutorials" ON song_tutorials;

CREATE POLICY "Users can view tutorials" ON song_tutorials
  FOR SELECT
  USING (
    status = 'approved'
    OR submitted_by_user_id = auth.uid()
    OR is_teacher()
  );

-- Fix student_resources SELECT policy
DROP POLICY IF EXISTS "Users can view approved resources or their own" ON student_resources;

CREATE POLICY "Users can view resources" ON student_resources
  FOR SELECT
  USING (
    status = 'approved'
    OR user_id = auth.uid()
    OR is_teacher()
  );

-- Also fix the UPDATE and DELETE policies to use is_teacher()
DROP POLICY IF EXISTS "Teachers can review tutorials" ON song_tutorials;
CREATE POLICY "Teachers can review tutorials" ON song_tutorials
  FOR UPDATE
  USING (is_teacher());

DROP POLICY IF EXISTS "Teachers can delete tutorials" ON song_tutorials;
CREATE POLICY "Teachers can delete tutorials" ON song_tutorials
  FOR DELETE
  USING (is_teacher());

DROP POLICY IF EXISTS "Teachers can review resources" ON student_resources;
CREATE POLICY "Teachers can review resources" ON student_resources
  FOR UPDATE
  USING (is_teacher());

DROP POLICY IF EXISTS "Teachers can delete resources" ON student_resources;
CREATE POLICY "Teachers can delete resources" ON student_resources
  FOR DELETE
  USING (is_teacher());
