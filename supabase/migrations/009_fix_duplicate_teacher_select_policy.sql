-- Fix duplicate SELECT policy on student_songs
-- Drop the old "Teachers can view class songs" policy and keep only the new one

DROP POLICY IF EXISTS "Teachers can view class songs" ON student_songs;

-- The new "Teachers can view student songs" policy already exists and should remain
-- No need to recreate it
