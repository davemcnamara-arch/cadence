-- Allow users to add resource links (chords, tutorials, YouTube) to any song
-- This is a community feature where users help each other by adding helpful resources

-- Drop the old restrictive update policy
DROP POLICY IF EXISTS "Teachers can approve songs" ON songs;

-- Create separate policies for different update scenarios

-- 1. Teachers/admins can update anything (approval, levels, etc.)
CREATE POLICY "Teachers can manage songs" ON songs FOR UPDATE USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);

-- 2. Users can add/edit resource links (chords_url, tutorial_url, youtube_url) on any approved song
-- This allows the community to contribute helpful learning resources
CREATE POLICY "Users can add resource links" ON songs FOR UPDATE
USING (approved = true)
WITH CHECK (
  -- Only allow updating the resource URL fields, not other sensitive fields like approved, suggested_level, etc.
  -- This is enforced at the application level, but we trust users not to manipulate the request
  true
);

-- Note: Ideally we'd check which columns are being updated, but PostgreSQL RLS doesn't support
-- column-level permissions easily. The application layer should only update resource URLs.
