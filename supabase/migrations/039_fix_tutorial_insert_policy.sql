-- Fix RLS policy for song_tutorials to allow any authenticated user to insert

-- Drop the existing restrictive policy
DROP POLICY IF EXISTS "Students can submit tutorials" ON song_tutorials;

-- Create a more permissive policy that allows any authenticated user to insert
CREATE POLICY "Authenticated users can submit tutorials" ON song_tutorials
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = submitted_by_user_id
  );

-- Also fix student_resources insert policy to allow teachers too
DROP POLICY IF EXISTS "Students can submit resources" ON student_resources;

CREATE POLICY "Authenticated users can submit resources" ON student_resources
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id
  );
