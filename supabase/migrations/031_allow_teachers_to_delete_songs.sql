-- Allow teachers to delete songs from the library
-- This gives teachers the ability to remove test songs or inappropriate content

-- Drop the old admin-only delete policy
DROP POLICY IF EXISTS "Admins can delete songs" ON songs;

-- Create new policy that allows both teachers and admins to delete songs
CREATE POLICY "Teachers and admins can delete songs" ON songs FOR DELETE USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);
