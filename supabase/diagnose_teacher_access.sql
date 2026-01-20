-- Diagnostic script: Run this while logged in AS THE TEACHER
-- This will check if the teacher can access the student and why

-- Step 1: Who are you logged in as?
SELECT
  auth.uid() as your_user_id,
  u.name as your_name,
  u.role as your_role
FROM users u
WHERE u.id = auth.uid();

-- Step 2: What classes do you own as a teacher?
SELECT
  c.id as class_id,
  c.name as class_name,
  c.class_code,
  c.teacher_id,
  COUNT(cm.user_id) as student_count
FROM classes c
LEFT JOIN class_members cm ON c.id = cm.class_id
WHERE c.teacher_id = auth.uid()
GROUP BY c.id, c.name, c.class_code, c.teacher_id;

-- Step 3: Which students are in YOUR classes?
SELECT
  c.class_code,
  c.name as class_name,
  u.id as student_id,
  u.name as student_name,
  cm.joined_at
FROM classes c
JOIN class_members cm ON c.id = cm.class_id
JOIN users u ON cm.user_id = u.id
WHERE c.teacher_id = auth.uid()
ORDER BY c.class_code, u.name;

-- Step 4: Does the specific student (68e46010-9ca3-4c0a-97bf-b1fb835928cb) appear in your results?
SELECT
  CASE
    WHEN EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = auth.uid()
        AND cm.user_id = '68e46010-9ca3-4c0a-97bf-b1fb835928cb'
    ) THEN 'YES - Student is in your class'
    ELSE 'NO - Student is NOT in any of your classes'
  END as student_access_check;

-- Step 5: Check if the policies exist
SELECT
  tablename,
  policyname,
  cmd as operation
FROM pg_policies
WHERE tablename = 'student_songs'
  AND policyname LIKE 'Teachers can%'
ORDER BY policyname;

-- Step 6: Test the actual policy logic for student_songs SELECT
-- This simulates what the RLS policy checks
SELECT
  '68e46010-9ca3-4c0a-97bf-b1fb835928cb' as student_id,
  CASE
    WHEN '68e46010-9ca3-4c0a-97bf-b1fb835928cb' IN (
      SELECT cm.user_id
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = auth.uid()
    ) THEN 'PASS - Policy should allow SELECT'
    ELSE 'FAIL - Policy will block SELECT'
  END as select_policy_test;

-- Step 7: Test the actual policy logic for student_songs INSERT
SELECT
  '68e46010-9ca3-4c0a-97bf-b1fb835928cb' as student_id,
  CASE
    WHEN '68e46010-9ca3-4c0a-97bf-b1fb835928cb' IN (
      SELECT cm.user_id
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = auth.uid()
    ) THEN 'PASS - Policy should allow INSERT'
    ELSE 'FAIL - Policy will block INSERT'
  END as insert_policy_test;
