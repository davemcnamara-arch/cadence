-- Allow teachers to modify their students' data in preview mode
-- This enables teachers to add/remove instruments and grade songs on behalf of students

-- Allow teachers to insert/update/delete student_progress for their students
CREATE POLICY "Teachers can insert student progress" ON student_progress
FOR INSERT
WITH CHECK (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

CREATE POLICY "Teachers can update student progress" ON student_progress
FOR UPDATE
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

CREATE POLICY "Teachers can delete student progress" ON student_progress
FOR DELETE
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

-- Allow teachers to insert/update/delete student_songs for their students
CREATE POLICY "Teachers can insert student songs" ON student_songs
FOR INSERT
WITH CHECK (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

CREATE POLICY "Teachers can update student songs" ON student_songs
FOR UPDATE
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

CREATE POLICY "Teachers can delete student songs" ON student_songs
FOR DELETE
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

-- Allow teachers to insert/update/delete song_ratings for their students
CREATE POLICY "Teachers can insert student ratings" ON song_ratings
FOR INSERT
WITH CHECK (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

CREATE POLICY "Teachers can update student ratings" ON song_ratings
FOR UPDATE
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

CREATE POLICY "Teachers can delete student ratings" ON song_ratings
FOR DELETE
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);
