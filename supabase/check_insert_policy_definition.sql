-- Show the exact policy definition for teacher INSERT
SELECT
  policyname,
  cmd,
  qual as using_clause,
  with_check as with_check_clause
FROM pg_policies
WHERE tablename = 'student_songs'
  AND policyname = 'Teachers can insert student songs';
