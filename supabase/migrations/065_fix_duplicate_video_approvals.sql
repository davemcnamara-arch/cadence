-- Fix duplicate YouTube video (and other link) approvals
--
-- Root causes:
-- 1. approve_pending_link() does not clean up other pending links for the
--    same song+link_type, so if two students submitted URLs for the same song
--    the teacher has to approve/reject each one individually.
-- 2. grade_song() uses case-sensitive title/artist matching, so "Bohemian
--    Rhapsody" and "bohemian rhapsody" create separate song records, each
--    with their own pending links.
-- 3. No DB-level constraint prevents concurrent inserts from creating
--    duplicate pending entries for the same song+link_type.
--
-- Fixes:
-- A. Add a partial unique index on pending_links to prevent duplicates.
-- B. Update approve_pending_link() to auto-reject siblings.
-- C. Update grade_song() to use case-insensitive song matching.
-- D. Clean up any existing duplicate pending links.

-- =============================================================================
-- A. Partial unique index: only one pending link per song+link_type at a time
-- =============================================================================

-- First, clean up existing duplicates so the index can be created.
-- Keep the oldest pending link for each song+link_type, reject the rest.
UPDATE pending_links pl
SET status = 'rejected',
    reviewed_at = NOW()
WHERE status = 'pending'
  AND id != (
    SELECT id FROM pending_links p2
    WHERE p2.song_id = pl.song_id
      AND p2.link_type = pl.link_type
      AND p2.status = 'pending'
    ORDER BY p2.submitted_at ASC
    LIMIT 1
  );

CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_links_one_per_song_type
  ON pending_links (song_id, link_type)
  WHERE status = 'pending';

-- =============================================================================
-- B. Update approve_pending_link() to auto-reject other pending links
--    for the same song + link_type
-- =============================================================================

CREATE OR REPLACE FUNCTION approve_pending_link(
  pending_link_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_song_id UUID;
  v_link_type TEXT;
  v_url TEXT;
BEGIN
  -- Get the pending link details
  SELECT song_id, link_type, url
  INTO v_song_id, v_link_type, v_url
  FROM pending_links
  WHERE id = pending_link_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending link not found or already processed';
  END IF;

  -- Update the song with the approved link
  IF v_link_type = 'youtube_url' THEN
    UPDATE songs SET youtube_url = v_url WHERE id = v_song_id;
  ELSIF v_link_type = 'chords_url' THEN
    UPDATE songs SET chords_url = v_url WHERE id = v_song_id;
  ELSIF v_link_type = 'tutorial_url' THEN
    UPDATE songs SET tutorial_url = v_url WHERE id = v_song_id;
  ELSIF v_link_type = 'bass_tab_url' THEN
    UPDATE songs SET bass_tab_url = v_url WHERE id = v_song_id;
  ELSIF v_link_type = 'drum_notation_url' THEN
    UPDATE songs SET drum_notation_url = v_url WHERE id = v_song_id;
  END IF;

  -- Mark the approved link
  UPDATE pending_links
  SET status = 'approved',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = pending_link_id;

  -- Auto-reject any OTHER pending links for the same song + link_type
  -- (e.g. another student submitted a YouTube URL for the same song)
  UPDATE pending_links
  SET status = 'rejected',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE song_id = v_song_id
    AND link_type = v_link_type
    AND status = 'pending'
    AND id != pending_link_id;
END;
$$;

-- =============================================================================
-- C. Update grade_song() with case-insensitive song matching and
--    ON CONFLICT handling for the new unique index
-- =============================================================================

DROP FUNCTION IF EXISTS grade_song(uuid, text, text, uuid, integer, jsonb, text, text, text, boolean, text, text, text);

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
BEGIN
  -- Get the current user (could be teacher or student)
  v_current_user_id := auth.uid();

  -- Check authorization using optimized helper function
  IF NOT can_grade_for_student(v_current_user_id, p_student_id) THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to grade for this student';
  END IF;

  -- Check if the current user is a teacher or admin
  v_is_teacher_or_admin := is_teacher_or_admin(v_current_user_id);

  -- Check if song exists using CASE-INSENSITIVE matching to prevent
  -- near-duplicate songs like "Bohemian Rhapsody" vs "bohemian rhapsody"
  SELECT id, youtube_url, chords_url, tutorial_url, bass_tab_url, drum_notation_url
  INTO v_song_id, v_existing_youtube_url, v_existing_chords_url, v_existing_tutorial_url, v_existing_bass_tab_url, v_existing_drum_notation_url
  FROM songs
  WHERE LOWER(title) = LOWER(p_title)
    AND LOWER(artist) = LOWER(p_artist)
  ORDER BY created_at ASC
  LIMIT 1;

  -- If song doesn't exist, create it
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
    -- Song already exists - handle URL updates
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
    SELECT id INTO v_student_song_id
    FROM student_songs
    WHERE user_id = p_student_id
      AND song_id = v_song_id
      AND instrument_id = p_instrument_id;

    IF v_student_song_id IS NULL THEN
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
