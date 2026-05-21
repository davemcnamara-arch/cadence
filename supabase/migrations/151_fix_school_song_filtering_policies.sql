-- ============================================================
-- MIGRATION 151: Fix school song filtering RLS policies
--
-- Migration 150 incorrectly restricted hide/release/curated-mode
-- actions to school_role = 'admin'. There is no school admin tier —
-- all teachers have equal access within their school.
--
-- Drops the admin-only policies and replaces them with
-- member-level equivalents. Also fixes set_school_curated_mode.
-- ============================================================

-- Drop old admin-only policies
DROP POLICY IF EXISTS "School admins can hide songs"            ON school_hidden_songs;
DROP POLICY IF EXISTS "School admins can unhide songs"          ON school_hidden_songs;
DROP POLICY IF EXISTS "School admins can release songs"         ON school_allowed_songs;
DROP POLICY IF EXISTS "School admins can remove released songs" ON school_allowed_songs;

-- school_hidden_songs: any school member can insert
CREATE POLICY "School members can hide songs"
  ON school_hidden_songs FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM school_members
      WHERE school_members.school_id = school_hidden_songs.school_id
        AND school_members.user_id = auth.uid()
    )
  );

-- school_hidden_songs: any school member can delete
CREATE POLICY "School members can unhide songs"
  ON school_hidden_songs FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM school_members
      WHERE school_members.school_id = school_hidden_songs.school_id
        AND school_members.user_id = auth.uid()
    )
  );

-- school_allowed_songs: any school member can insert
CREATE POLICY "School members can release songs"
  ON school_allowed_songs FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM school_members
      WHERE school_members.school_id = school_allowed_songs.school_id
        AND school_members.user_id = auth.uid()
    )
  );

-- school_allowed_songs: any school member can delete
CREATE POLICY "School members can remove released songs"
  ON school_allowed_songs FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM school_members
      WHERE school_members.school_id = school_allowed_songs.school_id
        AND school_members.user_id = auth.uid()
    )
  );

-- Fix set_school_curated_mode: allow any school member, not just school_role = 'admin'
CREATE OR REPLACE FUNCTION set_school_curated_mode(
  p_school_id UUID,
  p_enabled   BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID;
  v_is_member  BOOLEAN;
BEGIN
  v_user_id := auth.uid();

  SELECT EXISTS (
    SELECT 1 FROM school_members
    WHERE school_id = p_school_id AND user_id = v_user_id
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN json_build_object('success', false, 'message', 'Only school members can change this setting');
  END IF;

  UPDATE schools SET curated_mode = p_enabled WHERE id = p_school_id;

  RETURN json_build_object(
    'success', true,
    'message', CASE WHEN p_enabled THEN 'Curated mode enabled' ELSE 'Curated mode disabled' END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION set_school_curated_mode(UUID, BOOLEAN) TO authenticated;
