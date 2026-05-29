-- ============================================================
-- MIGRATION 155: Fix ambiguous "id" column reference in
--               get_class_timeline
--
-- Migration 154 added a DECLARE/SELECT to look up the class
-- teacher. Because the function RETURNS TABLE (id UUID, ...),
-- PL/pgSQL treats "id" as both an output-column variable and
-- a table column, causing error 42702 on "WHERE id = p_class_id".
-- Fix: qualify every bare "id" reference with its table name.
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
  SELECT c.teacher_id INTO v_class_teacher
  FROM classes c
  WHERE c.id = p_class_id;

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
