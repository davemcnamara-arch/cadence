-- Enroll student 68e46010-9ca3-4c0a-97bf-b1fb835928cb in class 8MS1
-- This will fix the permission errors by establishing the teacher-student relationship

INSERT INTO class_members (class_id, user_id)
VALUES (
  '3097e838-27bb-475b-88bc-79653ad64844',  -- Class 8MS1
  '68e46010-9ca3-4c0a-97bf-b1fb835928cb'   -- Student
);

-- Verify enrollment
SELECT
  c.name as class_name,
  c.class_code,
  s.name as student_name,
  cm.joined_at
FROM class_members cm
JOIN classes c ON cm.class_id = c.id
JOIN users s ON cm.user_id = s.id
WHERE cm.user_id = '68e46010-9ca3-4c0a-97bf-b1fb835928cb';
