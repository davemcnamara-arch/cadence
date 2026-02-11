-- Allow teachers/admins to view user names for pending content submitters
-- This fixes the "Submitted by Unknown" issue on the Flagged tab where
-- the users table RLS policy blocks the foreign key join from pending_links,
-- song_tutorials, and student_resources.
--
-- Uses SECURITY DEFINER functions to avoid infinite recursion: the users
-- table RLS cannot reference users or tables whose RLS references users.

-- Helper function to get IDs of users with pending submissions (bypasses RLS)
CREATE OR REPLACE FUNCTION get_pending_submitter_ids()
RETURNS SETOF UUID AS $$
  SELECT submitted_by_user_id FROM pending_links WHERE status = 'pending' AND submitted_by_user_id IS NOT NULL
  UNION
  SELECT submitted_by_user_id FROM song_tutorials WHERE status = 'pending' AND submitted_by_user_id IS NOT NULL
  UNION
  SELECT user_id FROM student_resources WHERE status = 'pending' AND user_id IS NOT NULL
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE POLICY "Teachers can view pending content submitters" ON users
  FOR SELECT
  USING (
    is_teacher()
    AND id IN (SELECT get_pending_submitter_ids())
  );
