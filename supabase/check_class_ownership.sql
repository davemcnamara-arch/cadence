-- Check class ownership and membership (no auth required)
-- This will tell us if the student is actually in a class owned by a teacher

-- Find the class with code 8MS1
SELECT
  c.id as class_id,
  c.name as class_name,
  c.class_code,
  c.teacher_id,
  t.name as teacher_name,
  t.email as teacher_email
FROM classes c
LEFT JOIN users t ON c.teacher_id = t.id
WHERE c.class_code = '8MS1';

-- Check if student 68e46010-9ca3-4c0a-97bf-b1fb835928cb is in class 8MS1
SELECT
  c.class_code,
  c.name as class_name,
  c.teacher_id,
  t.name as teacher_name,
  cm.user_id as student_id,
  s.name as student_name,
  cm.joined_at
FROM classes c
JOIN class_members cm ON c.id = cm.class_id
JOIN users s ON cm.user_id = s.id
LEFT JOIN users t ON c.teacher_id = t.id
WHERE c.class_code = '8MS1'
  AND cm.user_id = '68e46010-9ca3-4c0a-97bf-b1fb835928cb';

-- If the above returns 0 rows, the student is NOT in class 8MS1
-- If it returns 1 row, we'll see the teacher_id and can verify it matches
