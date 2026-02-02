-- Flag URLs for teacher approval when students grade songs
-- When a student grades a song and provides URLs (youtube, chords, tutorial),
-- those URLs should go to pending_links for teacher review instead of being
-- added directly to the songs table.
--
-- Teachers/admins can still add URLs directly when they grade.

-- ============================================================================
-- Helper function to check if user is a teacher or admin
-- ============================================================================
CREATE OR REPLACE FUNCTION is_teacher_or_admin(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE id = p_user_id
    AND role IN ('teacher', 'admin')
  );
$$;

-- ============================================================================
-- Update grade_song to flag student URLs for teacher approval
-- ============================================================================
DROP FUNCTION IF EXISTS grade_song(uuid, text, text, uuid, integer, jsonb, text, text, text, boolean, text);

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
  p_notes TEXT DEFAULT NULL
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
BEGIN
  -- Get the current user (could be teacher or student)
  v_current_user_id := auth.uid();

  -- Check authorization using optimized helper function
  IF NOT can_grade_for_student(v_current_user_id, p_student_id) THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to grade for this student';
  END IF;

  -- Check if the current user is a teacher or admin
  v_is_teacher_or_admin := is_teacher_or_admin(v_current_user_id);

  -- Check if song exists and get existing URLs
  SELECT id, youtube_url, chords_url, tutorial_url
  INTO v_song_id, v_existing_youtube_url, v_existing_chords_url, v_existing_tutorial_url
  FROM songs
  WHERE title = p_title
    AND artist = p_artist;

  -- If song doesn't exist, create it
  IF v_song_id IS NULL THEN
    -- For teachers/admins: add URLs directly
    -- For students: create song without URLs (URLs go to pending_links)
    INSERT INTO songs (
      title,
      artist,
      youtube_url,
      chords_url,
      tutorial_url,
      added_by_user_id,
      approved
    )
    VALUES (
      p_title,
      p_artist,
      CASE WHEN v_is_teacher_or_admin THEN p_youtube_url ELSE NULL END,
      CASE WHEN v_is_teacher_or_admin THEN p_chords_url ELSE NULL END,
      CASE WHEN v_is_teacher_or_admin THEN p_tutorial_url ELSE NULL END,
      v_current_user_id,
      true
    )
    RETURNING id INTO v_song_id;

    -- For students: add URLs to pending_links for teacher approval
    IF NOT v_is_teacher_or_admin THEN
      IF p_youtube_url IS NOT NULL AND p_youtube_url != '' THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'youtube_url', p_youtube_url, v_current_user_id);
      END IF;

      IF p_chords_url IS NOT NULL AND p_chords_url != '' THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'chords_url', p_chords_url, v_current_user_id);
      END IF;

      IF p_tutorial_url IS NOT NULL AND p_tutorial_url != '' THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'tutorial_url', p_tutorial_url, v_current_user_id);
      END IF;
    END IF;
  ELSE
    -- Song already exists - handle URL updates
    IF v_is_teacher_or_admin THEN
      -- Teachers/admins can update URLs directly
      UPDATE songs
      SET youtube_url = COALESCE(p_youtube_url, youtube_url),
          chords_url = COALESCE(p_chords_url, chords_url),
          tutorial_url = COALESCE(p_tutorial_url, tutorial_url)
      WHERE id = v_song_id;
    ELSE
      -- Students: add new/changed URLs to pending_links for approval
      -- Only add to pending if the URL is provided and different from existing
      IF p_youtube_url IS NOT NULL AND p_youtube_url != ''
         AND (v_existing_youtube_url IS NULL OR v_existing_youtube_url != p_youtube_url) THEN
        -- Check if there's already a pending link for this song/type
        IF NOT EXISTS (
          SELECT 1 FROM pending_links
          WHERE song_id = v_song_id
          AND link_type = 'youtube_url'
          AND status = 'pending'
        ) THEN
          INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
          VALUES (v_song_id, 'youtube_url', p_youtube_url, v_current_user_id);
        END IF;
      END IF;

      IF p_chords_url IS NOT NULL AND p_chords_url != ''
         AND (v_existing_chords_url IS NULL OR v_existing_chords_url != p_chords_url) THEN
        IF NOT EXISTS (
          SELECT 1 FROM pending_links
          WHERE song_id = v_song_id
          AND link_type = 'chords_url'
          AND status = 'pending'
        ) THEN
          INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
          VALUES (v_song_id, 'chords_url', p_chords_url, v_current_user_id);
        END IF;
      END IF;

      IF p_tutorial_url IS NOT NULL AND p_tutorial_url != ''
         AND (v_existing_tutorial_url IS NULL OR v_existing_tutorial_url != p_tutorial_url) THEN
        IF NOT EXISTS (
          SELECT 1 FROM pending_links
          WHERE song_id = v_song_id
          AND link_type = 'tutorial_url'
          AND status = 'pending'
        ) THEN
          INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
          VALUES (v_song_id, 'tutorial_url', p_tutorial_url, v_current_user_id);
        END IF;
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
    -- Update existing rating
    UPDATE song_ratings
    SET assessed_level = p_assessed_level,
        checklist_responses_json = p_checklist_responses_json,
        notes = p_notes,
        teacher_reviewed = FALSE,
        date_graded = NOW()
    WHERE id = v_existing_rating_id
    RETURNING id INTO v_rating_id;
  ELSE
    -- Insert new rating
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
