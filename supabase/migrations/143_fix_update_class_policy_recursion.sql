-- Fix infinite recursion in "Peer teachers can update classes in shared schools" policy.
--
-- Root cause: migration 097 used EXISTS (SELECT 1 FROM users WHERE role IN (...))
-- directly in the UPDATE policy. Querying users triggers the "Teachers can view
-- students in their classes" RLS on users, which queries classes, which re-triggers
-- the UPDATE policy — infinite recursion. Migration 093 fixed the same pattern for
-- INSERT by replacing the inline users query with is_teacher_or_admin() (SECURITY
-- DEFINER). Apply the same fix here.

DROP POLICY IF EXISTS "Peer teachers can update classes in shared schools" ON classes;

CREATE POLICY "Peer teachers can update classes in shared schools" ON classes
FOR UPDATE USING (
  school_id IS NOT NULL
  AND is_teacher_or_admin()
  AND teachers_share_school(auth.uid(), teacher_id)
);
