-- Allow teachers to view songs that their students are learning
-- This fixes the empty timeline issue where teachers couldn't see unapproved songs

CREATE POLICY "Teachers can view songs their students are learning" ON songs
FOR SELECT
USING (
  id IN (
    SELECT DISTINCT ss.song_id
    FROM student_songs ss
    JOIN class_members cm ON ss.user_id = cm.user_id
    JOIN classes c ON cm.class_id = c.id
    WHERE c.teacher_id = auth.uid()
  )
);
