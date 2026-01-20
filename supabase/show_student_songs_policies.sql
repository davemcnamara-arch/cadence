-- Show all policies on student_songs to find the duplicate/conflict
SELECT
  policyname,
  cmd as operation,
  qual as using_expression,
  with_check as with_check_expression
FROM pg_policies
WHERE tablename = 'student_songs'
ORDER BY policyname;
