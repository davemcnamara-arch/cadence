-- Step 1: Check if the old policy is gone
SELECT
  COUNT(*) as old_policy_count,
  CASE
    WHEN COUNT(*) = 0 THEN '✓ OLD POLICY REMOVED'
    ELSE '✗ OLD POLICY STILL EXISTS - Run: DROP POLICY "Teachers can view class songs" ON student_songs;'
  END as status
FROM pg_policies
WHERE tablename = 'student_songs'
  AND policyname = 'Teachers can view class songs';

-- Step 2: Verify only 4 teacher policies exist now
SELECT
  COUNT(*) as teacher_policy_count,
  CASE
    WHEN COUNT(*) = 4 THEN '✓ CORRECT - 4 policies'
    WHEN COUNT(*) = 5 THEN '✗ STILL 5 - Old policy not dropped'
    ELSE '✗ UNEXPECTED COUNT'
  END as status
FROM pg_policies
WHERE tablename = 'student_songs'
  AND policyname LIKE 'Teachers can%';

-- Step 3: List all teacher policies (should be exactly 4)
SELECT
  policyname,
  cmd as operation
FROM pg_policies
WHERE tablename = 'student_songs'
  AND policyname LIKE 'Teachers can%'
ORDER BY cmd, policyname;

-- Step 4: Test if INSERT policy would allow this specific insert
-- Run this while logged in as the TEACHER
SELECT
  CASE
    WHEN '68e46010-9ca3-4c0a-97bf-b1fb835928cb' IN (
      SELECT cm.user_id
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = auth.uid()
    ) THEN '✓ PASS - INSERT should work'
    ELSE '✗ FAIL - Student not in teacher''s class OR not logged in as teacher'
  END as insert_test;
