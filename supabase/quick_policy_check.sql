-- Quick diagnostic: Check if policies exist (no auth required)
-- Run this in Supabase SQL Editor

-- Check if the new teacher policies exist
SELECT
  tablename,
  policyname,
  cmd as operation,
  CASE
    WHEN cmd = 'SELECT' THEN 'Allows viewing data'
    WHEN cmd = 'INSERT' THEN 'Allows adding data'
    WHEN cmd = 'UPDATE' THEN 'Allows modifying data'
    WHEN cmd = 'DELETE' THEN 'Allows removing data'
    ELSE cmd
  END as description
FROM pg_policies
WHERE tablename IN ('student_songs', 'student_progress', 'song_ratings', 'resource_ratings')
  AND policyname LIKE 'Teachers can%'
ORDER BY tablename, cmd, policyname;

-- Expected result: Should show 16 policies total
-- - 4 for student_songs (view, insert, update, delete)
-- - 4 for student_progress (view, insert, update, delete)
-- - 4 for song_ratings (view, insert, update, delete)
-- - 4 for resource_ratings (view, insert, update, delete)

-- Count them
SELECT
  tablename,
  COUNT(*) as policy_count
FROM pg_policies
WHERE tablename IN ('student_songs', 'student_progress', 'song_ratings', 'resource_ratings')
  AND policyname LIKE 'Teachers can%'
GROUP BY tablename
ORDER BY tablename;

-- If any table shows 0 policies, the migration didn't run
-- If any table shows < 4 policies, the migration only partially ran
