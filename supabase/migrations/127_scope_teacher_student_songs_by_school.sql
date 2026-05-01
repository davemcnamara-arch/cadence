-- ============================================================
-- MIGRATION 127: Add optional p_school_id filter to
--               get_teacher_student_songs
--
-- When p_school_id is supplied the function returns only songs
-- for students in classes that belong to that school, matching
-- the scope of the school tab stats.  Passing NULL preserves the
-- existing all-schools behaviour.
-- ============================================================

DROP FUNCTION IF EXISTS get_teacher_student_songs();

CREATE OR REPLACE FUNCTION get_teacher_student_songs(
  p_school_id UUID DEFAULT NULL
)
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
    AND (p_school_id IS NULL OR c.school_id = p_school_id)
  ORDER BY ss.id, c.id;
END;
$$;

GRANT EXECUTE ON FUNCTION get_teacher_student_songs(UUID) TO authenticated;
