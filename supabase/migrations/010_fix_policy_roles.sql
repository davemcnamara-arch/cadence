-- Fix: Add 'authenticated' role to all teacher policies
-- The policies were only applying to 'public' role, but logged-in users use 'authenticated'

-- First, drop and recreate all teacher policies with correct roles

-- student_progress policies
DROP POLICY IF EXISTS "Teachers can view student progress" ON student_progress;
CREATE POLICY "Teachers can view student progress" ON student_progress
FOR SELECT TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can insert student progress" ON student_progress;
CREATE POLICY "Teachers can insert student progress" ON student_progress
FOR INSERT TO authenticated, public
WITH CHECK (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can update student progress" ON student_progress;
CREATE POLICY "Teachers can update student progress" ON student_progress
FOR UPDATE TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can delete student progress" ON student_progress;
CREATE POLICY "Teachers can delete student progress" ON student_progress
FOR DELETE TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

-- student_songs policies
DROP POLICY IF EXISTS "Teachers can view student songs" ON student_songs;
CREATE POLICY "Teachers can view student songs" ON student_songs
FOR SELECT TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can insert student songs" ON student_songs;
CREATE POLICY "Teachers can insert student songs" ON student_songs
FOR INSERT TO authenticated, public
WITH CHECK (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can update student songs" ON student_songs;
CREATE POLICY "Teachers can update student songs" ON student_songs
FOR UPDATE TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can delete student songs" ON student_songs;
CREATE POLICY "Teachers can delete student songs" ON student_songs
FOR DELETE TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

-- song_ratings policies
DROP POLICY IF EXISTS "Teachers can view student ratings" ON song_ratings;
CREATE POLICY "Teachers can view student ratings" ON song_ratings
FOR SELECT TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can insert student ratings" ON song_ratings;
CREATE POLICY "Teachers can insert student ratings" ON song_ratings
FOR INSERT TO authenticated, public
WITH CHECK (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can update student ratings" ON song_ratings;
CREATE POLICY "Teachers can update student ratings" ON song_ratings
FOR UPDATE TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can delete student ratings" ON song_ratings;
CREATE POLICY "Teachers can delete student ratings" ON song_ratings
FOR DELETE TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

-- resource_ratings policies
DROP POLICY IF EXISTS "Teachers can view student resource ratings" ON resource_ratings;
CREATE POLICY "Teachers can view student resource ratings" ON resource_ratings
FOR SELECT TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can insert student resource ratings" ON resource_ratings;
CREATE POLICY "Teachers can insert student resource ratings" ON resource_ratings
FOR INSERT TO authenticated, public
WITH CHECK (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can update student resource ratings" ON resource_ratings;
CREATE POLICY "Teachers can update student resource ratings" ON resource_ratings
FOR UPDATE TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Teachers can delete student resource ratings" ON resource_ratings;
CREATE POLICY "Teachers can delete student resource ratings" ON resource_ratings
FOR DELETE TO authenticated, public
USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);
