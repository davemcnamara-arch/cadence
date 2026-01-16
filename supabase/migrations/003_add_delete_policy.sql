-- Add DELETE policy for student_progress table
-- This allows students to remove instruments they're tracking

CREATE POLICY "Students can delete own progress" ON student_progress
FOR DELETE
USING (user_id = auth.uid());
