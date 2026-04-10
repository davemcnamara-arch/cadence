-- ============================================================
-- MIGRATION 122: Fix grade_song() to handle soft-deleted songs
--
-- Problem 1 (song stays invisible after re-add):
--   grade_song() looks up songs by title+artist WITHOUT filtering
--   deleted_at IS NULL. When a song has been soft-deleted and a
--   user grades it again, the function finds the soft-deleted record
--   and reuses its song_id — but never clears deleted_at. Every UI
--   query filters deleted_at IS NULL, so the song stays invisible
--   in the song library and "currently learning" sections.
--
-- Problem 2 (student_songs unique constraint violation on re-add):
--   The "add to learning" block inside grade_song() checks for an
--   existing student_songs row WITHOUT filtering deleted_at IS NULL,
--   then does a bare INSERT. If a soft-deleted student_songs row
--   exists for the same (user_id, song_id, instrument_id), the
--   INSERT violates the unique constraint.
--
-- Fix:
--   1. Song lookup: prefer active songs; if only a soft-deleted one
--      exists, restore it (set deleted_at = NULL) before continuing.
--   2. Student_songs "add to learning": restore soft-deleted rows
--      instead of inserting (same pattern as add_student_song()).
-- ============================================================

CREATE OR REPLACE FUNCTION grade_song(
  p_student_id UUID,
  p_title TEXT,
  p_artist TEXT,
  p_instrument_id UUID,
  p_assessed_level INTEGER,
  p_checklist_responses_json JSONB,
  p_youtube_url TEXT DEFAULT NULL,
  p_chords_url TEXT DEFAULT NULL,
  p_tutorial_url TEXT DEFAULT NULL,
  p_add_to_learning BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL,
  p_bass_tab_url TEXT DEFAULT NULL,
  p_drum_notation_url TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_song_id UUID;
  v_rating_id UUID;
  v_student_song_id UUID;
  v_existing_rating_id UUID;
  v_result JSON;
  v_is_teacher_or_admin BOOLEAN;
  v_existing_youtube_url TEXT;
  v_existing_chords_url TEXT;
  v_existing_tutorial_url TEXT;
  v_existing_bass_tab_url TEXT;
  v_existing_drum_notation_url TEXT;
  v_song_is_deleted BOOLEAN;
BEGIN
  -- Get the current user (could be teacher or student)
  v_current_user_id := auth.uid();

  -- Check authorization using optimized helper function
  IF NOT can_grade_for_student(v_current_user_id, p_student_id) THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to grade for this student';
  END IF;

  -- Check if the current user is a teacher or admin
  v_is_teacher_or_admin := is_teacher_or_admin(v_current_user_id);

  -- Check if an active (non-deleted) song exists using case-insensitive matching.
  -- We prefer active songs; soft-deleted ones are handled separately below.
  SELECT id, youtube_url, chords_url, tutorial_url, bass_tab_url, drum_notation_url
  INTO v_song_id, v_existing_youtube_url, v_existing_chords_url, v_existing_tutorial_url, v_existing_bass_tab_url, v_existing_drum_notation_url
  FROM songs
  WHERE LOWER(title) = LOWER(p_title)
    AND LOWER(artist) = LOWER(p_artist)
    AND deleted_at IS NULL
  ORDER BY created_at ASC
  LIMIT 1;

  -- If no active song found, check for a soft-deleted one and restore it
  IF v_song_id IS NULL THEN
    SELECT id, youtube_url, chords_url, tutorial_url, bass_tab_url, drum_notation_url
    INTO v_song_id, v_existing_youtube_url, v_existing_chords_url, v_existing_tutorial_url, v_existing_bass_tab_url, v_existing_drum_notation_url
    FROM songs
    WHERE LOWER(title) = LOWER(p_title)
      AND LOWER(artist) = LOWER(p_artist)
      AND deleted_at IS NOT NULL
    ORDER BY created_at ASC
    LIMIT 1;

    IF v_song_id IS NOT NULL THEN
      -- Restore the soft-deleted song so it becomes visible again
      UPDATE songs
      SET deleted_at = NULL
      WHERE id = v_song_id;
    END IF;
  END IF;

  -- If song still doesn't exist, create it
  IF v_song_id IS NULL THEN
    -- Note: tutorial_url is no longer set here; tutorials are managed
    -- via the song_tutorials table (inserted by the client after grading)
    INSERT INTO songs (
      title,
      artist,
      youtube_url,
      chords_url,
      tutorial_url,
      bass_tab_url,
      drum_notation_url,
      added_by_user_id,
      approved
    )
    VALUES (
      p_title,
      p_artist,
      CASE WHEN v_is_teacher_or_admin THEN p_youtube_url ELSE NULL END,
      CASE WHEN v_is_teacher_or_admin THEN p_chords_url ELSE NULL END,
      CASE WHEN v_is_teacher_or_admin THEN p_tutorial_url ELSE NULL END,
      CASE WHEN v_is_teacher_or_admin THEN p_bass_tab_url ELSE NULL END,
      CASE WHEN v_is_teacher_or_admin THEN p_drum_notation_url ELSE NULL END,
      v_current_user_id,
      true
    )
    RETURNING id INTO v_song_id;

    -- For students: add URLs to pending_links for teacher approval
    -- Note: tutorial_url is NOT added here — it goes to song_tutorials
    -- (inserted by the client) to avoid duplicate approval requests.
    -- ON CONFLICT DO NOTHING handles the race condition where two students
    -- create the same song simultaneously.
    IF NOT v_is_teacher_or_admin THEN
      IF p_youtube_url IS NOT NULL AND p_youtube_url != '' THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'youtube_url', p_youtube_url, v_current_user_id)
        ON CONFLICT (song_id, link_type) WHERE status = 'pending' DO NOTHING;
      END IF;

      IF p_chords_url IS NOT NULL AND p_chords_url != '' THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'chords_url', p_chords_url, v_current_user_id)
        ON CONFLICT (song_id, link_type) WHERE status = 'pending' DO NOTHING;
      END IF;

      IF p_bass_tab_url IS NOT NULL AND p_bass_tab_url != '' THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'bass_tab_url', p_bass_tab_url, v_current_user_id)
        ON CONFLICT (song_id, link_type) WHERE status = 'pending' DO NOTHING;
      END IF;

      IF p_drum_notation_url IS NOT NULL AND p_drum_notation_url != '' THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'drum_notation_url', p_drum_notation_url, v_current_user_id)
        ON CONFLICT (song_id, link_type) WHERE status = 'pending' DO NOTHING;
      END IF;
    END IF;
  ELSE
    -- Song already exists (active or just restored) - handle URL updates
    IF v_is_teacher_or_admin THEN
      UPDATE songs
      SET youtube_url = COALESCE(p_youtube_url, youtube_url),
          chords_url = COALESCE(p_chords_url, chords_url),
          tutorial_url = COALESCE(p_tutorial_url, tutorial_url),
          bass_tab_url = COALESCE(p_bass_tab_url, bass_tab_url),
          drum_notation_url = COALESCE(p_drum_notation_url, drum_notation_url)
      WHERE id = v_song_id;
    ELSE
      -- Students: add new/changed URLs to pending_links for approval
      -- Note: tutorial_url is NOT added here — it goes to song_tutorials
      -- ON CONFLICT DO NOTHING prevents duplicates atomically
      IF p_youtube_url IS NOT NULL AND p_youtube_url != ''
         AND (v_existing_youtube_url IS NULL OR v_existing_youtube_url != p_youtube_url) THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'youtube_url', p_youtube_url, v_current_user_id)
        ON CONFLICT (song_id, link_type) WHERE status = 'pending' DO NOTHING;
      END IF;

      IF p_chords_url IS NOT NULL AND p_chords_url != ''
         AND (v_existing_chords_url IS NULL OR v_existing_chords_url != p_chords_url) THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'chords_url', p_chords_url, v_current_user_id)
        ON CONFLICT (song_id, link_type) WHERE status = 'pending' DO NOTHING;
      END IF;

      IF p_bass_tab_url IS NOT NULL AND p_bass_tab_url != ''
         AND (v_existing_bass_tab_url IS NULL OR v_existing_bass_tab_url != p_bass_tab_url) THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'bass_tab_url', p_bass_tab_url, v_current_user_id)
        ON CONFLICT (song_id, link_type) WHERE status = 'pending' DO NOTHING;
      END IF;

      IF p_drum_notation_url IS NOT NULL AND p_drum_notation_url != ''
         AND (v_existing_drum_notation_url IS NULL OR v_existing_drum_notation_url != p_drum_notation_url) THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'drum_notation_url', p_drum_notation_url, v_current_user_id)
        ON CONFLICT (song_id, link_type) WHERE status = 'pending' DO NOTHING;
      END IF;
    END IF;
  END IF;

  -- Check if rating already exists
  SELECT id INTO v_existing_rating_id
  FROM song_ratings
  WHERE song_id = v_song_id
    AND instrument_id = p_instrument_id
    AND user_id = p_student_id;

  -- Update or insert rating
  IF v_existing_rating_id IS NOT NULL THEN
    UPDATE song_ratings
    SET assessed_level = p_assessed_level,
        checklist_responses_json = p_checklist_responses_json,
        notes = p_notes,
        teacher_reviewed = FALSE,
        date_graded = NOW()
    WHERE id = v_existing_rating_id
    RETURNING id INTO v_rating_id;
  ELSE
    INSERT INTO song_ratings (
      song_id,
      instrument_id,
      assessed_level,
      user_id,
      checklist_responses_json,
      notes,
      teacher_reviewed
    )
    VALUES (
      v_song_id,
      p_instrument_id,
      p_assessed_level,
      p_student_id,
      p_checklist_responses_json,
      p_notes,
      FALSE
    )
    RETURNING id INTO v_rating_id;
  END IF;

  -- Add to learning if requested
  IF p_add_to_learning THEN
    -- Check for an active student_songs row first
    SELECT id INTO v_student_song_id
    FROM student_songs
    WHERE user_id       = p_student_id
      AND song_id       = v_song_id
      AND instrument_id = p_instrument_id
      AND deleted_at IS NULL;

    IF v_student_song_id IS NULL THEN
      -- Check for a soft-deleted row and restore it
      SELECT id INTO v_student_song_id
      FROM student_songs
      WHERE user_id       = p_student_id
        AND song_id       = v_song_id
        AND instrument_id = p_instrument_id
        AND deleted_at IS NOT NULL
      LIMIT 1;

      IF v_student_song_id IS NOT NULL THEN
        UPDATE student_songs
        SET deleted_at     = NULL,
            status         = 'learning',
            date_started   = NOW(),
            date_completed = NULL
        WHERE id = v_student_song_id;
      ELSE
        INSERT INTO student_songs (
          user_id,
          song_id,
          instrument_id,
          status
        )
        VALUES (
          p_student_id,
          v_song_id,
          p_instrument_id,
          'learning'
        )
        RETURNING id INTO v_student_song_id;
      END IF;
    END IF;
  END IF;

  -- Return success result
  v_result := json_build_object(
    'success', true,
    'song_id', v_song_id,
    'rating_id', v_rating_id,
    'student_song_id', v_student_song_id
  );

  RETURN v_result;
END;
$$;
