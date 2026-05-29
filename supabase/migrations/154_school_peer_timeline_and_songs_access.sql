-- ============================================================
-- MIGRATION 154: Allow same-school peers to view class timeline
--               and student songs when browsing from the school tab
--
-- Problem: get_class_timeline blocked access for school members
-- who aren't the class owner or co-teacher, raising a permission
-- error. And get_teacher_student_songs only returns songs for
-- classes owned by the caller, so a colleague's class always
-- showed empty.
--
-- Fix:
--   1. Update get_class_timeline to allow same-school peers
--      (same pattern as migration 146 for get_class_students)
--   2. Add get_class_student_songs(p_class_id) — a class-scoped
--      song fetch with identical auth rules, used by the front-end
--      when viewing a school peer's class
-- ============================================================


-- ============================================================
-- 1. get_class_timeline
--    Old: admin OR teacher/co-teacher
--    New: + same-school peer teacher
-- ============================================================
CREATE OR REPLACE FUNCTION get_class_timeline(p_class_id UUID)
RETURNS TABLE (
  id               UUID,
  user_id          UUID,
  song_id          UUID,
  instrument_id    UUID,
  status           TEXT,
  date_started     TIMESTAMP WITH TIME ZONE,
  date_completed   TIMESTAMP WITH TIME ZONE,
  notes            TEXT,
  student_name     TEXT,
  song_title       TEXT,
  song_artist      TEXT,
  instrument_icon  TEXT,
  instrument_name  TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_class_teacher UUID;
BEGIN
  SELECT teacher_id INTO v_class_teacher
  FROM classes
  WHERE id = p_class_id;

  IF NOT is_admin()
     AND NOT is_class_teacher_or_coteacher(p_class_id)
     AND NOT (
       v_class_teacher IS NOT NULL
       AND teachers_share_school(auth.uid(), v_class_teacher)
     )
  THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this class';
  END IF;

  RETURN QUERY
  SELECT
    ss.id,
    ss.user_id,
    ss.song_id,
    ss.instrument_id,
    ss.status,
    ss.date_started,
    ss.date_completed,
    ss.notes,
    u.name  AS student_name,
    s.title AS song_title,
    s.artist AS song_artist,
    i.icon  AS instrument_icon,
    i.name  AS instrument_name
  FROM student_songs ss
  JOIN class_members cm ON ss.user_id = cm.user_id
  JOIN users u ON ss.user_id = u.id
  JOIN songs s ON ss.song_id = s.id
  JOIN instruments i ON ss.instrument_id = i.id
  WHERE cm.class_id = p_class_id
  ORDER BY ss.date_started DESC
  LIMIT 20;
END;
$$;

GRANT EXECUTE ON FUNCTION get_class_timeline(UUID) TO authenticated;


-- ============================================================
-- 2. get_class_student_songs(p_class_id)
--    Returns all currently-learning student songs for one class.
--    Auth: admin OR teacher/co-teacher OR same-school peer.
--    Returns the same column set as get_teacher_student_songs so
--    the front-end can reuse its rendering logic.
-- ============================================================
CREATE OR REPLACE FUNCTION get_class_student_songs(p_class_id UUID)
RETURNS TABLE (
  student_song_id   UUID,
  student_id        UUID,
  student_name      TEXT,
  song_id           UUID,
  title             TEXT,
  artist            TEXT,
  youtube_url       TEXT,
  chords_url        TEXT,
  bass_tab_url      TEXT,
  drum_notation_url TEXT,
  instrument_id     UUID,
  instrument_name   TEXT,
  instrument_icon   TEXT,
  class_id          UUID,
  class_name        TEXT,
  date_started      DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_class_teacher UUID;
BEGIN
  SELECT teacher_id INTO v_class_teacher
  FROM classes
  WHERE id = p_class_id;

  IF NOT is_admin()
     AND NOT is_class_teacher_or_coteacher(p_class_id)
     AND NOT (
       v_class_teacher IS NOT NULL
       AND teachers_share_school(auth.uid(), v_class_teacher)
     )
  THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (ss.id)
    ss.id                 AS student_song_id,
    u.id                  AS student_id,
    u.name                AS student_name,
    so.id                 AS song_id,
    so.title              AS title,
    so.artist             AS artist,
    so.youtube_url        AS youtube_url,
    so.chords_url         AS chords_url,
    so.bass_tab_url       AS bass_tab_url,
    so.drum_notation_url  AS drum_notation_url,
    i.id                  AS instrument_id,
    i.name                AS instrument_name,
    i.icon                AS instrument_icon,
    c.id                  AS class_id,
    c.name                AS class_name,
    ss.date_started::DATE AS date_started
  FROM student_songs ss
  JOIN users u          ON u.id  = ss.user_id
  JOIN songs so         ON so.id = ss.song_id
  JOIN instruments i    ON i.id  = ss.instrument_id
  JOIN class_members cm ON cm.user_id = u.id
  JOIN classes c        ON c.id  = cm.class_id
  WHERE ss.status = 'learning'
    AND ss.deleted_at IS NULL
    AND c.id = p_class_id
    AND c.archived IS NOT TRUE
  ORDER BY ss.id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_class_student_songs(UUID) TO authenticated;
