-- ============================================================
-- MIGRATION 091: Fix function overloading errors (PGRST203)
--
-- Problem 1: get_teacher_classes has two overloads:
--   - (UUID, BOOLEAN)        created in 080_add_school_to_classes
--   - (UUID, BOOLEAN, UUID)  created in 090_filter_by_school
--   CREATE OR REPLACE with a different signature creates a NEW
--   overload rather than replacing the old one. PostgREST
--   (PGRST203) cannot resolve which to call.
--   Fix: drop the old 2-param version; the 3-param version
--   (with p_school_id DEFAULT NULL) is fully backward-compatible.
--
-- Problem 2: search_teacher_students has two overloads:
--   - ()      created in 059/068
--   - (UUID)  created in 090_filter_by_school
--   Same fix: drop the old no-param version.
--
-- Problem 3: Direct REST query to schools?select=id returns 500
--   for admin users. The school_members RLS policy (migration 075)
--   references school_members itself, causing infinite recursion
--   when schools is queried directly. Fix: add an admin bypass
--   policy using the existing is_admin() security-definer function.
-- ============================================================

-- ============================================================
-- 1. Drop old 2-param get_teacher_classes overload
-- ============================================================
DROP FUNCTION IF EXISTS public.get_teacher_classes(UUID, BOOLEAN);

-- ============================================================
-- 2. Drop old no-param search_teacher_students overload
-- ============================================================
DROP FUNCTION IF EXISTS public.search_teacher_students();

-- ============================================================
-- 3. Add admin bypass policy on schools table
--    Allows admins to SELECT all schools without needing a
--    school_members row, and avoids the recursive RLS path
--    that causes HTTP 500.
-- ============================================================
DROP POLICY IF EXISTS "Admins can view all schools" ON schools;

CREATE POLICY "Admins can view all schools"
  ON schools FOR SELECT
  USING (is_admin());
