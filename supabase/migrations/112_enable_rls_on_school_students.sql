-- Migration 112: Enable RLS on school_students table
-- Fixes security lint error: rls_disabled_in_public for public.school_students
--
-- All write operations (INSERT/DELETE) on school_students are performed
-- exclusively through SECURITY DEFINER functions which bypass RLS.
-- These SELECT policies cover direct table access.

ALTER TABLE school_students ENABLE ROW LEVEL SECURITY;

-- School members (teachers/admins) can view students in their school
CREATE POLICY "School members can view students in their school"
  ON school_students FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM school_members
      WHERE school_members.school_id = school_students.school_id
        AND school_members.user_id = auth.uid()
    )
  );

-- Students can view their own school membership records
CREATE POLICY "Students can view their own school membership"
  ON school_students FOR SELECT
  USING (user_id = auth.uid());

-- Admins can view all school_students records
CREATE POLICY "Admins can view all school students"
  ON school_students FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
    )
  );
