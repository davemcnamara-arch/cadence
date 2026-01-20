-- Fix grade_song function to remove spotify_url parameter
-- The spotify_url column was removed in migration 006_remove_spotify.sql
-- This migration updates the function to match the current schema

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
  p_add_to_learning BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_is_authorized BOOLEAN;
  v_song_id UUID;
  v_rating_id UUID;
  v_student_song_id UUID;
  v_result JSON;
BEGIN
  -- Get the current user (could be teacher or student)
  v_current_user_id := auth.uid();

  -- Check if current user is authorized to grade for this student
  -- Either: (1) they are the student themselves, OR
  --         (2) they are a teacher with the student in their class
  SELECT (
    v_current_user_id = p_student_id
    OR
    EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_current_user_id
        AND cm.user_id = p_student_id
    )
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
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
      true -- Auto-approve for MVP
    )
    RETURNING id INTO v_song_id;
  END IF;

  -- Add rating
  INSERT INTO song_ratings (
    song_id,
    instrument_id,
    assessed_level,
    user_id,
    checklist_responses_json
  )
  VALUES (
    v_song_id,
    p_instrument_id,
    p_assessed_level,
    p_student_id,
    p_checklist_responses_json
  )
  RETURNING id INTO v_rating_id;

  -- Add to learning if requested
  IF p_add_to_learning THEN
    -- Check if already exists
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

  -- Return result
  v_result := json_build_object(
    'song_id', v_song_id,
    'rating_id', v_rating_id,
    'student_song_id', v_student_song_id
  );

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION grade_song(UUID, TEXT, TEXT, UUID, INTEGER, JSONB, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated;
