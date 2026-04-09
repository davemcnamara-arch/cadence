-- ============================================================
-- MIGRATION 120: Fix add_student_song for soft-deleted rows
--                and peer school teacher permissions
--
-- Problem 1 (Permission denied - 400):
--   add_student_song only allows direct teachers or the student
--   themselves. Peer school teachers (allowed to preview students
--   since migration 118) get "Permission denied" when trying to
--   add a song in preview mode.
--
-- Problem 2 (400 on re-add after removal):
--   Song removal is a soft-delete (deleted_at = NOW()). The
--   UNIQUE(song_id, instrument_id, user_id) constraint means the
--   row still exists. add_student_song's duplicate check does not
--   filter deleted_at IS NULL, so re-adding the same
--   song+instrument finds the soft-deleted row and raises
--   "Student is already tracking this song" (400). Even if that
--   check were bypassed, the INSERT would fail the unique
--   constraint anyway.
--
-- Fix:
--   1. Expand permission check to match migration 118/119 pattern
--      (direct teacher OR peer school teacher OR admin).
--   2. Change the duplicate check to only look at non-deleted rows.
--   3. If a soft-deleted row already exists for the same
--      (user_id, song_id, instrument_id), restore it (set
--      deleted_at = NULL, reset status/date_started) instead of
--      inserting a new row.
-- ============================================================

CREATE OR REPLACE FUNCTION add_student_song(
  p_student_id    UUID,
  p_song_id       UUID,
  p_instrument_id UUID,
  p_status        TEXT DEFAULT 'learning'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id    UUID;
  v_has_access   BOOLEAN;
  v_existing_id  UUID;
  v_result       JSON;
BEGIN
  v_caller_id := auth.uid();

  -- Caller must be the student themselves, a direct teacher,
  -- a peer school teacher, or a global admin.
  SELECT (
    v_caller_id = p_student_id

    OR is_admin()

    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_caller_id
        AND cm.user_id = p_student_id
    )

    OR EXISTS (
      SELECT 1
      FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      JOIN school_members sm ON sm.school_id = c.school_id
      WHERE cm.user_id = p_student_id
        AND sm.user_id = v_caller_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  -- Check for an active (non-deleted) duplicate
  IF EXISTS (
    SELECT 1 FROM student_songs
    WHERE user_id       = p_student_id
      AND song_id       = p_song_id
      AND instrument_id = p_instrument_id
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Student is already tracking this song';
  END IF;

  -- If a soft-deleted row exists for the same combination, restore it
  SELECT id INTO v_existing_id
  FROM student_songs
  WHERE user_id       = p_student_id
    AND song_id       = p_song_id
    AND instrument_id = p_instrument_id
    AND deleted_at IS NOT NULL
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    UPDATE student_songs
    SET
      deleted_at   = NULL,
      status       = p_status,
      date_started = NOW(),
      date_completed = NULL
    WHERE id = v_existing_id
    RETURNING json_build_object(
      'id',            id,
      'user_id',       user_id,
      'song_id',       song_id,
      'instrument_id', instrument_id,
      'status',        status,
      'date_started',  date_started
    ) INTO v_result;
  ELSE
    INSERT INTO student_songs (user_id, song_id, instrument_id, status)
    VALUES (p_student_id, p_song_id, p_instrument_id, p_status)
    RETURNING json_build_object(
      'id',            id,
      'user_id',       user_id,
      'song_id',       song_id,
      'instrument_id', instrument_id,
      'status',        status,
      'date_started',  date_started
    ) INTO v_result;
  END IF;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION add_student_song(UUID, UUID, UUID, TEXT) TO authenticated;
