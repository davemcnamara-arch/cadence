-- ============================================================
-- MIGRATION 150: School-level song filtering
--
-- Allows school admins to control which songs appear in the
-- library for their school members (teachers and students).
--
-- Two modes, toggled per school:
--
--   Blocklist mode (default, curated_mode = FALSE):
--     Songs in school_hidden_songs are invisible to school members.
--     All other songs appear as normal.
--
--   Curated mode (curated_mode = TRUE):
--     Only songs in school_allowed_songs are visible.
--     School admins see the full library to manage the allowed list;
--     all other members see only the released songs.
--
-- Changes:
--   1. Add curated_mode to schools
--   2. Create school_hidden_songs table (blocklist)
--   3. Create school_allowed_songs table (allowlist)
--   4. RLS policies for both tables
--   5. Update get_my_schools() to include curated_mode
--   6. RPC: set_school_curated_mode
--   7. RPC: get_student_school_filter (for students)
-- ============================================================

-- ============================================================
-- 1. Add curated_mode to schools
-- ============================================================
ALTER TABLE schools
  ADD COLUMN IF NOT EXISTS curated_mode BOOLEAN NOT NULL DEFAULT FALSE;

-- ============================================================
-- 2. school_hidden_songs (blocklist mode)
-- ============================================================
CREATE TABLE IF NOT EXISTS school_hidden_songs (
  school_id  UUID NOT NULL REFERENCES schools(id)  ON DELETE CASCADE,
  song_id    UUID NOT NULL REFERENCES songs(id)    ON DELETE CASCADE,
  hidden_by  UUID NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  hidden_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (school_id, song_id)
);

CREATE INDEX IF NOT EXISTS idx_school_hidden_songs_school ON school_hidden_songs(school_id);

-- ============================================================
-- 3. school_allowed_songs (curated/allowlist mode)
-- ============================================================
CREATE TABLE IF NOT EXISTS school_allowed_songs (
  school_id   UUID NOT NULL REFERENCES schools(id)  ON DELETE CASCADE,
  song_id     UUID NOT NULL REFERENCES songs(id)    ON DELETE CASCADE,
  allowed_by  UUID NOT NULL REFERENCES users(id)    ON DELETE CASCADE,
  allowed_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (school_id, song_id)
);

CREATE INDEX IF NOT EXISTS idx_school_allowed_songs_school ON school_allowed_songs(school_id);

-- ============================================================
-- 4. RLS policies
-- ============================================================
ALTER TABLE school_hidden_songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_allowed_songs ENABLE ROW LEVEL SECURITY;

-- school_hidden_songs: any school member can read
CREATE POLICY "School members can view hidden songs list"
  ON school_hidden_songs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM school_members
      WHERE school_members.school_id = school_hidden_songs.school_id
        AND school_members.user_id = auth.uid()
    )
  );

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

-- school_allowed_songs: any school member can read
CREATE POLICY "School members can view allowed songs list"
  ON school_allowed_songs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM school_members
      WHERE school_members.school_id = school_allowed_songs.school_id
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

-- ============================================================
-- 5. Update get_my_schools() to include curated_mode
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_schools()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_result  JSON;
BEGIN
  v_user_id := auth.uid();

  SELECT COALESCE(
    json_agg(
      json_build_object(
        'id',                      s.id,
        'name',                    s.name,
        'join_code',               s.join_code,
        'school_role',             sm.school_role,
        'joined_at',               sm.joined_at,
        'shared_class_visibility', s.shared_class_visibility,
        'curated_mode',            s.curated_mode
      )
      ORDER BY sm.joined_at ASC
    ),
    '[]'::json
  ) INTO v_result
  FROM school_members sm
  JOIN schools s ON s.id = sm.school_id
  WHERE sm.user_id = v_user_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_schools() TO authenticated;

-- ============================================================
-- 6. RPC: set_school_curated_mode
--    Toggles curated mode on/off. School admins only.
-- ============================================================
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
  v_user_id   UUID;
  v_caller_role TEXT;
BEGIN
  v_user_id := auth.uid();

  SELECT school_role INTO v_caller_role
  FROM school_members
  WHERE school_id = p_school_id AND user_id = v_user_id;

  IF v_caller_role IS NULL THEN
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

-- ============================================================
-- 7. RPC: get_student_school_filter
--    Called by students (who have no school_members row).
--    Derives their school from their class membership and
--    returns the relevant song filter for that school.
--
--    Returns:
--      null                          – student has no school
--      { school_id, curated_mode: false, song_ids: [...] }  – hidden IDs
--      { school_id, curated_mode: true,  song_ids: [...] }  – allowed IDs
-- ============================================================
CREATE OR REPLACE FUNCTION get_student_school_filter()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id    UUID;
  v_school_id  UUID;
  v_curated    BOOLEAN;
  v_song_ids   UUID[];
BEGIN
  v_user_id := auth.uid();

  -- Find the student's school via their class membership
  SELECT c.school_id INTO v_school_id
  FROM class_members cm
  JOIN classes c ON c.id = cm.class_id
  WHERE cm.user_id = v_user_id
    AND c.school_id IS NOT NULL
  LIMIT 1;

  IF v_school_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT curated_mode INTO v_curated FROM schools WHERE id = v_school_id;

  IF v_curated THEN
    SELECT array_agg(song_id) INTO v_song_ids
    FROM school_allowed_songs
    WHERE school_id = v_school_id;
  ELSE
    SELECT array_agg(song_id) INTO v_song_ids
    FROM school_hidden_songs
    WHERE school_id = v_school_id;
  END IF;

  RETURN json_build_object(
    'school_id',    v_school_id,
    'curated_mode', v_curated,
    'song_ids',     COALESCE(v_song_ids, ARRAY[]::UUID[])
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_student_school_filter() TO authenticated;
