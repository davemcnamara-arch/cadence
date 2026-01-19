-- Fix the recursive RLS policy for teachers viewing students
-- The original policy tries to query class_members to check if teacher can see a student,
-- but when we query class_members with a users join, it creates circular recursion

-- Drop the problematic policy
DROP POLICY IF EXISTS "Teachers can view students in their classes" ON users;

-- Recreate with a simpler approach using EXISTS
CREATE POLICY "Teachers can view students in their classes" ON users FOR SELECT USING (
  role = 'student' AND EXISTS (
    SELECT 1
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
      AND cm.user_id = users.id
  )
);
