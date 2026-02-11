-- Allow teachers/admins to view user names for pending content submitters
-- This fixes the "Submitted by Unknown" issue on the Flagged tab where
-- the users table RLS policy blocks the foreign key join from pending_links,
-- song_tutorials, and student_resources.

CREATE POLICY "Teachers can view pending content submitters" ON users
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role IN ('teacher', 'admin')
    )
    AND (
      id IN (SELECT submitted_by_user_id FROM pending_links WHERE status = 'pending')
      OR id IN (SELECT submitted_by_user_id FROM song_tutorials WHERE status = 'pending')
      OR id IN (SELECT user_id FROM student_resources WHERE status = 'pending')
    )
  );
