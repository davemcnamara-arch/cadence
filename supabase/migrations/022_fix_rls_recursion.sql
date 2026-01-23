-- Fix infinite recursion in RLS policy for songs table
-- The issue: "Users can add resource links" policy checks approved = true,
-- which queries the songs table, triggering the policy again = infinite recursion

-- Drop the problematic policy
DROP POLICY IF EXISTS "Users can add resource links" ON songs;

-- Recreate without the recursion issue
-- Students can only submit links via pending_links (not direct UPDATE)
-- Teachers can update directly via their separate policy
-- This policy is now removed since we have link moderation

-- Verify teachers still have their policy
-- Teachers can manage songs - this policy is safe because it doesn't query songs table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename = 'songs'
    AND policyname = 'Teachers can manage songs'
  ) THEN
    CREATE POLICY "Teachers can manage songs" ON songs FOR UPDATE USING (
      EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
    );
  END IF;
END $$;
