-- Fix the "Teachers can view pending content submitters" policy that was
-- created without the SECURITY DEFINER helper, causing infinite recursion.

-- Drop the broken policy
DROP POLICY IF EXISTS "Teachers can view pending content submitters" ON users;

-- Create helper function to get IDs of users with pending submissions (bypasses RLS)
CREATE OR REPLACE FUNCTION get_pending_submitter_ids()
RETURNS SETOF UUID AS $$
  SELECT submitted_by_user_id FROM pending_links WHERE status = 'pending' AND submitted_by_user_id IS NOT NULL
  UNION
  SELECT submitted_by_user_id FROM song_tutorials WHERE status = 'pending' AND submitted_by_user_id IS NOT NULL
  UNION
  SELECT user_id FROM student_resources WHERE status = 'pending' AND user_id IS NOT NULL
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Recreate policy using SECURITY DEFINER functions to avoid recursion
CREATE POLICY "Teachers can view pending content submitters" ON users
  FOR SELECT
  USING (
    is_teacher()
    AND id IN (SELECT get_pending_submitter_ids())
  );
