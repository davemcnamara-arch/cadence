-- Verification script: Check if policies exist and if student is in teacher's class
-- Run this to troubleshoot permission issues

-- Step 1: Check if the policies were created
SELECT
  schemaname,
  tablename,
  policyname,
  cmd,
  qual
FROM pg_policies
WHERE tablename IN ('student_songs', 'student_progress', 'song_ratings', 'resource_ratings')
  AND policyname LIKE 'Teachers can%'
ORDER BY tablename, policyname;

-- Step 2: Check class membership
-- Replace 'YOUR_STUDENT_ID' with: 68e46010-9ca3-4c0a-97bf-b1fb835928cb
-- This query shows which teachers have access to this student
SELECT
  c.id as class_id,
  c.name as class_name,
  c.teacher_id,
  u_teacher.name as teacher_name,
  cm.user_id as student_id,
  u_student.name as student_name,
  cm.joined_at
FROM classes c
JOIN class_members cm ON c.id = cm.class_id
JOIN users u_teacher ON c.teacher_id = u_teacher.id
JOIN users u_student ON cm.user_id = u_student.id
WHERE cm.user_id = '68e46010-9ca3-4c0a-97bf-b1fb835928cb';

-- Step 3: Check current user (should be the teacher)
SELECT
  auth.uid() as current_user_id,
  u.name as current_user_name,
  u.role as current_user_role
FROM users u
WHERE u.id = auth.uid();

-- Step 4: Test if current teacher has access to this student
SELECT
  CASE
    WHEN '68e46010-9ca3-4c0a-97bf-b1fb835928cb' IN (
      SELECT cm.user_id
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = auth.uid()
    ) THEN 'YES - Teacher has access to this student'
    ELSE 'NO - Student is not in teacher''s class'
  END as access_check;
