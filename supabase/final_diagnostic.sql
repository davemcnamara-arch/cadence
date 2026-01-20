-- Final diagnostic: Student IS enrolled, so why the 406/403 errors?

-- 1. Confirm student IS in the class
SELECT
  'Student enrollment status' as check_type,
  c.name as class_name,
  c.class_code,
  t.name as teacher_name,
  t.id as teacher_id,
  s.name as student_name,
  cm.joined_at
FROM class_members cm
JOIN classes c ON cm.class_id = c.id
JOIN users s ON cm.user_id = s.id
JOIN users t ON c.teacher_id = t.id
WHERE cm.user_id = '68e46010-9ca3-4c0a-97bf-b1fb835928cb';

-- 2. Check if duplicate SELECT policy still exists (THIS IS THE LIKELY CULPRIT)
SELECT
  'SELECT policy check' as check_type,
  policyname,
  cmd as operation
FROM pg_policies
WHERE tablename = 'student_songs'
  AND policyname LIKE 'Teachers can%'
  AND cmd = 'SELECT'
ORDER BY policyname;

-- Expected: Should show ONLY 1 SELECT policy ("Teachers can view student songs")
-- If it shows 2, the old "Teachers can view class songs" is still there

-- 3. Count all teacher policies on student_songs
SELECT
  'Policy count' as check_type,
  COUNT(*) as teacher_policies,
  CASE
    WHEN COUNT(*) = 4 THEN '✓ CORRECT'
    WHEN COUNT(*) = 5 THEN '✗ DUPLICATE - Old policy still exists'
    ELSE '✗ UNEXPECTED'
  END as status
FROM pg_policies
WHERE tablename = 'student_songs'
  AND policyname LIKE 'Teachers can%';

-- 4. Show ALL policies on student_songs
SELECT
  'All policies on student_songs' as check_type,
  policyname,
  cmd as operation
FROM pg_policies
WHERE tablename = 'student_songs'
ORDER BY cmd, policyname;
