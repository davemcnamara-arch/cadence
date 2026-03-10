-- ============================================================
-- MIGRATION 093: Fix infinite recursion in classes INSERT policy
--
-- Root cause: The "Teachers can create classes" policy in 092
-- called EXISTS (SELECT 1 FROM users WHERE role IN ('teacher','admin')).
-- Querying users triggered the "Teachers can view students in their
-- classes" RLS policy on users, which in turn queries classes —
-- causing infinite recursion.
--
-- Fix: Move the role check into a SECURITY DEFINER function so it
-- bypasses RLS on users (mirrors how is_admin() works).
-- ============================================================

-- Helper: is the current user a teacher or admin?
-- SECURITY DEFINER bypasses users RLS, breaking the recursion loop.
CREATE OR REPLACE FUNCTION is_teacher_or_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role IN ('teacher', 'admin')
  );
END;
$$;

GRANT EXECUTE ON FUNCTION is_teacher_or_admin() TO authenticated;

-- Recreate the INSERT policy using the safe SECURITY DEFINER helper
DROP POLICY IF EXISTS "Teachers can create classes" ON classes;

CREATE POLICY "Teachers can create classes" ON classes
FOR INSERT WITH CHECK (
  -- Creating a class for yourself
  teacher_id = auth.uid()
  OR
  -- Creating a class for a peer teacher at the same school
  (
    is_teacher_or_admin()
    AND teachers_share_school(auth.uid(), teacher_id)
  )
);
