-- Allow users to add resource links (chords, tutorials, YouTube) to any song
-- This is a community feature where users help each other by adding helpful resources
-- This migration is idempotent - safe to run multiple times

-- Drop all existing UPDATE policies on songs table
DROP POLICY IF EXISTS "Teachers can approve songs" ON songs;
DROP POLICY IF EXISTS "Teachers can manage songs" ON songs;
DROP POLICY IF EXISTS "Users can add resource links" ON songs;

-- Create separate policies for different update scenarios

-- 1. Teachers/admins can update anything (approval, levels, etc.)
CREATE POLICY "Teachers can manage songs" ON songs FOR UPDATE USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);

-- 2. Authenticated users can add/edit resource links on any approved song
-- This allows the community to contribute helpful learning resources
CREATE POLICY "Users can add resource links" ON songs FOR UPDATE
USING (
  approved = true AND
  auth.uid() IS NOT NULL
)
WITH CHECK (true);

-- Note: Ideally we'd check which columns are being updated, but PostgreSQL RLS doesn't support
-- column-level permissions easily. The application layer should only update resource URLs.
