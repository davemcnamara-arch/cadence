-- ============================================================
-- MIGRATION 152: Fix RLS recursion on school song filter tables
--
-- The policies added in migrations 150/151 query school_members
-- directly inside USING/WITH CHECK clauses. school_members has
-- its own self-referential RLS policy, causing infinite recursion
-- and a 500 on every query.
--
-- Fix: introduce a SECURITY DEFINER helper (same pattern as
-- school_has_shared_visibility in migration 095) so the membership
-- check bypasses RLS and breaks the recursion.
-- ============================================================

-- Helper: is the calling user a member of the given school?
CREATE OR REPLACE FUNCTION is_school_member(p_school_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM school_members
    WHERE school_id = p_school_id
      AND user_id = auth.uid()
  )
$$;

GRANT EXECUTE ON FUNCTION is_school_member(UUID) TO authenticated;

-- Recreate all six policies using the helper

DROP POLICY IF EXISTS "School members can view hidden songs list" ON school_hidden_songs;
DROP POLICY IF EXISTS "School members can hide songs"            ON school_hidden_songs;
DROP POLICY IF EXISTS "School members can unhide songs"          ON school_hidden_songs;

CREATE POLICY "School members can view hidden songs list"
  ON school_hidden_songs FOR SELECT
  USING (is_school_member(school_id));

CREATE POLICY "School members can hide songs"
  ON school_hidden_songs FOR INSERT
  WITH CHECK (is_school_member(school_id));

CREATE POLICY "School members can unhide songs"
  ON school_hidden_songs FOR DELETE
  USING (is_school_member(school_id));

DROP POLICY IF EXISTS "School members can view allowed songs list"   ON school_allowed_songs;
DROP POLICY IF EXISTS "School members can release songs"             ON school_allowed_songs;
DROP POLICY IF EXISTS "School members can remove released songs"     ON school_allowed_songs;

CREATE POLICY "School members can view allowed songs list"
  ON school_allowed_songs FOR SELECT
  USING (is_school_member(school_id));

CREATE POLICY "School members can release songs"
  ON school_allowed_songs FOR INSERT
  WITH CHECK (is_school_member(school_id));

CREATE POLICY "School members can remove released songs"
  ON school_allowed_songs FOR DELETE
  USING (is_school_member(school_id));
