-- Find what classes actually exist in the database
SELECT
  c.id as class_id,
  c.name as class_name,
  c.class_code,
  c.teacher_id,
  t.name as teacher_name,
  c.created_at
FROM classes c
LEFT JOIN users t ON c.teacher_id = t.id
ORDER BY c.created_at DESC;

-- Find which class the student (68e46010-9ca3-4c0a-97bf-b1fb835928cb) is actually in
SELECT
  c.id as class_id,
  c.name as class_name,
  c.class_code,
  c.teacher_id,
  t.name as teacher_name,
  cm.joined_at
FROM class_members cm
JOIN classes c ON cm.class_id = c.id
LEFT JOIN users t ON c.teacher_id = t.id
WHERE cm.user_id = '68e46010-9ca3-4c0a-97bf-b1fb835928cb';

-- Find all teachers
SELECT
  id as teacher_id,
  name as teacher_name,
  email as teacher_email,
  role
FROM users
WHERE role = 'teacher'
ORDER BY name;
