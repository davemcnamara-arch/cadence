-- Fix for infinite recursion in RLS policies

-- Drop the problematic class_members policies
DROP POLICY IF EXISTS "Class members can view classmates" ON class_members;
DROP POLICY IF EXISTS "Teachers can manage class members" ON class_members;
DROP POLICY IF EXISTS "Students can join classes" ON class_members;

-- Recreate with non-recursive logic
CREATE POLICY "Teachers can manage their class members" ON class_members FOR ALL USING (
  class_id IN (SELECT id FROM classes WHERE teacher_id = auth.uid())
);

CREATE POLICY "Students can view their own class membership" ON class_members FOR SELECT USING (
  user_id = auth.uid()
);

CREATE POLICY "Students can join classes" ON class_members FOR INSERT WITH CHECK (
  user_id = auth.uid()
);

-- Also fix student_songs policy that might have similar issues
DROP POLICY IF EXISTS "Classmates can see what others are learning" ON student_songs;

-- Simplified version without recursion
CREATE POLICY "Students can view songs in their classes" ON student_songs FOR SELECT USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM classes c
    JOIN class_members cm1 ON c.id = cm1.class_id
    JOIN class_members cm2 ON c.id = cm2.class_id
    WHERE cm1.user_id = auth.uid()
    AND cm2.user_id = student_songs.user_id
  )
);

-- Fix student_progress policy
DROP POLICY IF EXISTS "Teachers can view class progress" ON student_progress;

CREATE POLICY "Teachers can view their students progress" ON student_progress FOR SELECT USING (
  user_id IN (
    SELECT cm.user_id
    FROM classes c
    JOIN class_members cm ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);
