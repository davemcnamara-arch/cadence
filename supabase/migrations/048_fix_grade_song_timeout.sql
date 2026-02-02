-- Fix grade_song timeout issue
-- The authorization check was causing timeouts due to RLS policy recursion
-- on classes and class_members tables.
--
-- Solution: Create a helper function that efficiently checks teacher-student
-- relationship, and update grade_song to use a simpler authorization approach.

-- ============================================================================
-- 1. Create helper function to check if user is authorized to grade for student
-- This function bypasses RLS issues by using SECURITY DEFINER
-- ============================================================================
CREATE OR REPLACE FUNCTION can_grade_for_student(p_grader_id UUID, p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  -- User can grade for themselves
  SELECT p_grader_id = p_student_id
  OR
  -- Or user is a teacher who has this student in one of their classes
  EXISTS (
    SELECT 1
    FROM classes c
    INNER JOIN class_members cm ON cm.class_id = c.id
    WHERE c.teacher_id = p_grader_id
      AND cm.user_id = p_student_id
    LIMIT 1
  )
  OR
  -- Or user is an admin
  EXISTS (
    SELECT 1 FROM users WHERE id = p_grader_id AND role = 'admin'
  );
$$;

-- ============================================================================
-- 2. Update grade_song to use the optimized helper function
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
BEGIN
  -- Get the current user (could be teacher or student)
  v_current_user_id := auth.uid();

  -- Check authorization using optimized helper function
  IF NOT can_grade_for_student(v_current_user_id, p_student_id) THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to grade for this student';
  END IF;

  -- Check if song exists
  SELECT id INTO v_song_id
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
      added_by_user_id,
      approved
    )
    VALUES (
      p_title,
      p_artist,
      p_youtube_url,
      p_chords_url,
      p_tutorial_url,
      v_current_user_id,
      true
    )
    RETURNING id INTO v_song_id;
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
