-- Add separate URL columns for bass tab and drum notation resources
-- Previously all instruments shared the single chords_url column,
-- which meant setting a bass tab link would overwrite a chords link.

ALTER TABLE songs
ADD COLUMN bass_tab_url TEXT,
ADD COLUMN drum_notation_url TEXT;

-- Update the pending_links CHECK constraint to allow new link types
ALTER TABLE pending_links DROP CONSTRAINT IF EXISTS pending_links_link_type_check;
ALTER TABLE pending_links ADD CONSTRAINT pending_links_link_type_check
  CHECK (link_type IN ('youtube_url', 'chords_url', 'tutorial_url', 'bass_tab_url', 'drum_notation_url'));

-- Update approve_pending_link to handle new link types
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

  -- Mark the pending link as approved
  UPDATE pending_links
  SET status = 'approved',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = pending_link_id;
END;
$$;

-- Update grade_song to accept new URL parameters
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

  -- Check if song exists and get existing URLs
  SELECT id, youtube_url, chords_url, tutorial_url, bass_tab_url, drum_notation_url
  INTO v_song_id, v_existing_youtube_url, v_existing_chords_url, v_existing_tutorial_url, v_existing_bass_tab_url, v_existing_drum_notation_url
  FROM songs
  WHERE title = p_title
    AND artist = p_artist;

  -- If song doesn't exist, create it
  IF v_song_id IS NULL THEN
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

      IF p_bass_tab_url IS NOT NULL AND p_bass_tab_url != '' THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'bass_tab_url', p_bass_tab_url, v_current_user_id);
      END IF;

      IF p_drum_notation_url IS NOT NULL AND p_drum_notation_url != '' THEN
        INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
        VALUES (v_song_id, 'drum_notation_url', p_drum_notation_url, v_current_user_id);
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
      IF p_youtube_url IS NOT NULL AND p_youtube_url != ''
         AND (v_existing_youtube_url IS NULL OR v_existing_youtube_url != p_youtube_url) THEN
        IF NOT EXISTS (
          SELECT 1 FROM pending_links
          WHERE song_id = v_song_id AND link_type = 'youtube_url' AND status = 'pending'
        ) THEN
          INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
          VALUES (v_song_id, 'youtube_url', p_youtube_url, v_current_user_id);
        END IF;
      END IF;

      IF p_chords_url IS NOT NULL AND p_chords_url != ''
         AND (v_existing_chords_url IS NULL OR v_existing_chords_url != p_chords_url) THEN
        IF NOT EXISTS (
          SELECT 1 FROM pending_links
          WHERE song_id = v_song_id AND link_type = 'chords_url' AND status = 'pending'
        ) THEN
          INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
          VALUES (v_song_id, 'chords_url', p_chords_url, v_current_user_id);
        END IF;
      END IF;

      IF p_tutorial_url IS NOT NULL AND p_tutorial_url != ''
         AND (v_existing_tutorial_url IS NULL OR v_existing_tutorial_url != p_tutorial_url) THEN
        IF NOT EXISTS (
          SELECT 1 FROM pending_links
          WHERE song_id = v_song_id AND link_type = 'tutorial_url' AND status = 'pending'
        ) THEN
          INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
          VALUES (v_song_id, 'tutorial_url', p_tutorial_url, v_current_user_id);
        END IF;
      END IF;

      IF p_bass_tab_url IS NOT NULL AND p_bass_tab_url != ''
         AND (v_existing_bass_tab_url IS NULL OR v_existing_bass_tab_url != p_bass_tab_url) THEN
        IF NOT EXISTS (
          SELECT 1 FROM pending_links
          WHERE song_id = v_song_id AND link_type = 'bass_tab_url' AND status = 'pending'
        ) THEN
          INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
          VALUES (v_song_id, 'bass_tab_url', p_bass_tab_url, v_current_user_id);
        END IF;
      END IF;

      IF p_drum_notation_url IS NOT NULL AND p_drum_notation_url != ''
         AND (v_existing_drum_notation_url IS NULL OR v_existing_drum_notation_url != p_drum_notation_url) THEN
        IF NOT EXISTS (
          SELECT 1 FROM pending_links
          WHERE song_id = v_song_id AND link_type = 'drum_notation_url' AND status = 'pending'
        ) THEN
          INSERT INTO pending_links (song_id, link_type, url, submitted_by_user_id)
          VALUES (v_song_id, 'drum_notation_url', p_drum_notation_url, v_current_user_id);
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

-- Update get_student_detail to include new URL fields
-- (This function builds a JSON response with song data)
CREATE OR REPLACE FUNCTION get_student_detail(p_student_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSON;
  v_caller_id UUID;
BEGIN
  v_caller_id := auth.uid();

  -- Verify caller has access (is the student, their teacher, or admin)
  IF v_caller_id != p_student_id
     AND NOT EXISTS (
       SELECT 1 FROM class_members cm
       JOIN classes c ON c.id = cm.class_id
       WHERE cm.user_id = p_student_id
         AND c.teacher_id = v_caller_id
     )
     AND NOT EXISTS (
       SELECT 1 FROM users WHERE id = v_caller_id AND role = 'admin'
     )
  THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT json_agg(
    json_build_object(
      'id', ss.id,
      'song_id', ss.song_id,
      'instrument_id', ss.instrument_id,
      'status', ss.status,
      'date_started', ss.date_started,
      'date_completed', ss.date_completed,
      'songs', json_build_object(
        'id', s.id,
        'title', s.title,
        'artist', s.artist,
        'chords_url', s.chords_url,
        'tutorial_url', s.tutorial_url,
        'youtube_url', s.youtube_url,
        'bass_tab_url', s.bass_tab_url,
        'drum_notation_url', s.drum_notation_url
      ),
      'instruments', json_build_object(
        'id', i.id,
        'name', i.name,
        'icon', i.icon
      ),
      'resource_ratings', (
        SELECT json_build_object(
          'chords', COALESCE(json_agg(rr.chords_rating) FILTER (WHERE rr.chords_rating IS NOT NULL), '[]'::json),
          'tutorial', COALESCE(json_agg(rr.tutorial_rating) FILTER (WHERE rr.tutorial_rating IS NOT NULL), '[]'::json)
        )
        FROM resource_ratings rr
        WHERE rr.student_song_id = ss.id
      )
    )
  ) INTO v_result
  FROM student_songs ss
  JOIN songs s ON ss.song_id = s.id
  JOIN instruments i ON ss.instrument_id = i.id
  WHERE ss.user_id = p_student_id;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;
