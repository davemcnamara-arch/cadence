-- ============================================================
-- MIGRATION 121: Filter soft-deleted student_songs from teacher views
--
-- Problem:
--   Migration 110 changed song removal to a soft-delete
--   (deleted_at = NOW()) instead of a hard DELETE. However, the
--   three teacher-facing RPC functions that query student_songs
--   were not updated to filter out rows where deleted_at IS NOT NULL.
--
--   Symptom: a student removes a song (soft-delete), then re-adds
--   it on the correct instrument (new active row). When a teacher
--   clicks "X students" on a song card, the modal shows the student
--   twice — once on the old (soft-deleted) instrument and once on
--   the new instrument.
--
-- Fix:
--   Add `AND ss.deleted_at IS NULL` to the WHERE clause of:
--     1. get_song_students_for_teacher  (used by the modal)
--     2. get_teacher_student_song_counts (used by the badge count)
--     3. get_teacher_student_songs       (used by the student songs list)
-- ============================================================

-- ============================================================
-- 1. Fix get_song_students_for_teacher
-- ============================================================
CREATE OR REPLACE FUNCTION get_song_students_for_teacher(
  p_song_id UUID,
  p_include_archived BOOLEAN DEFAULT false
)
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  status TEXT,
  instrument_id UUID,
  instrument_name TEXT,
  instrument_icon TEXT,
  date_started TIMESTAMPTZ,
  date_completed TIMESTAMPTZ,
  class_name TEXT,
  class_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin')) THEN
    RAISE EXCEPTION 'Permission denied: must be a teacher or admin';
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (ss.user_id, ss.instrument_id)
    ss.user_id,
    u.name,
    ss.status,
    ss.instrument_id,
    i.name AS instrument_name,
    i.icon AS instrument_icon,
    ss.date_started,
    ss.date_completed,
    c.name AS class_name,
    c.id AS class_id
  FROM student_songs ss
  INNER JOIN users u ON ss.user_id = u.id
  INNER JOIN instruments i ON ss.instrument_id = i.id
  INNER JOIN class_members cm ON ss.user_id = cm.user_id
  INNER JOIN classes c ON cm.class_id = c.id
  WHERE ss.song_id = p_song_id
    AND ss.deleted_at IS NULL
    AND c.teacher_id = auth.uid()
    AND (p_include_archived = true OR c.archived IS NOT TRUE)
  ORDER BY ss.user_id, ss.instrument_id, ss.date_started DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_song_students_for_teacher(UUID, BOOLEAN) TO authenticated;

-- ============================================================
-- 2. Fix get_teacher_student_song_counts
-- ============================================================
CREATE OR REPLACE FUNCTION get_teacher_student_song_counts(
  p_include_archived BOOLEAN DEFAULT false
)
RETURNS TABLE (
  song_id UUID,
  learning_count BIGINT,
  mastered_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin')) THEN
    RAISE EXCEPTION 'Permission denied: must be a teacher or admin';
  END IF;

  RETURN QUERY
  SELECT
    ss.song_id,
    COUNT(*) FILTER (WHERE ss.status = 'learning') AS learning_count,
    COUNT(*) FILTER (WHERE ss.status = 'mastered') AS mastered_count
  FROM student_songs ss
  INNER JOIN class_members cm ON ss.user_id = cm.user_id
  INNER JOIN classes c ON cm.class_id = c.id
  WHERE c.teacher_id = auth.uid()
    AND ss.deleted_at IS NULL
    AND (p_include_archived = true OR c.archived IS NOT TRUE)
  GROUP BY ss.song_id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_teacher_student_song_counts(BOOLEAN) TO authenticated;

-- ============================================================
-- 3. Fix get_teacher_student_songs
-- ============================================================
DROP FUNCTION IF EXISTS get_teacher_student_songs();
CREATE OR REPLACE FUNCTION get_teacher_student_songs()
RETURNS TABLE (
  student_song_id    UUID,
  student_id         UUID,
  student_name       TEXT,
  song_id            UUID,
  title              TEXT,
  artist             TEXT,
  youtube_url        TEXT,
  chords_url         TEXT,
  bass_tab_url       TEXT,
  drum_notation_url  TEXT,
  instrument_id      UUID,
  instrument_name    TEXT,
  instrument_icon    TEXT,
  class_id           UUID,
  class_name         TEXT,
  date_started       DATE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (ss.id)
    ss.id                  AS student_song_id,
    u.id                   AS student_id,
    u.name                 AS student_name,
    so.id                  AS song_id,
    so.title               AS title,
    so.artist              AS artist,
    so.youtube_url         AS youtube_url,
    so.chords_url          AS chords_url,
    so.bass_tab_url        AS bass_tab_url,
    so.drum_notation_url   AS drum_notation_url,
    i.id                   AS instrument_id,
    i.name                 AS instrument_name,
    i.icon                 AS instrument_icon,
    c.id                   AS class_id,
    c.name                 AS class_name,
    ss.date_started::DATE  AS date_started
  FROM student_songs ss
  JOIN users u          ON u.id  = ss.user_id
  JOIN songs so         ON so.id = ss.song_id
  JOIN instruments i    ON i.id  = ss.instrument_id
  JOIN class_members cm ON cm.user_id = u.id
  JOIN classes c        ON c.id  = cm.class_id
  WHERE ss.status = 'learning'
    AND ss.deleted_at IS NULL
    AND c.teacher_id = auth.uid()
    AND c.archived IS NOT TRUE
  ORDER BY ss.id, c.id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_teacher_student_songs() TO authenticated;
