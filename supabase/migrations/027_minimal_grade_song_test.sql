-- Minimal test version of grade_song to isolate the timeout issue
-- This removes the authorization check temporarily to see if that's causing the hang

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
  v_song_id UUID;
  v_rating_id UUID;
  v_existing_rating_id UUID;
  v_result JSON;
BEGIN
  -- TEMPORARY: Skip authorization check to test if that's causing the timeout
  -- TODO: Re-add authorization after testing

  RAISE NOTICE 'Starting grade_song for student: %', p_student_id;

  -- Check if song exists
  SELECT id INTO v_song_id
  FROM songs
  WHERE title = p_title
    AND artist = p_artist;

  RAISE NOTICE 'Found song_id: %', v_song_id;

  -- If song doesn't exist, create it
  IF v_song_id IS NULL THEN
    RAISE NOTICE 'Creating new song';
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
      auth.uid(),
      true
    )
    RETURNING id INTO v_song_id;
    RAISE NOTICE 'Created song_id: %', v_song_id;
  END IF;

  -- Check if rating already exists
  RAISE NOTICE 'Checking for existing rating';
  SELECT id INTO v_existing_rating_id
  FROM song_ratings
  WHERE song_id = v_song_id
    AND instrument_id = p_instrument_id
    AND user_id = p_student_id;

  RAISE NOTICE 'Existing rating_id: %', v_existing_rating_id;

  -- Update or insert rating
  IF v_existing_rating_id IS NOT NULL THEN
    RAISE NOTICE 'Updating existing rating';
    UPDATE song_ratings
    SET assessed_level = p_assessed_level,
        checklist_responses_json = p_checklist_responses_json,
        notes = p_notes,
        teacher_reviewed = FALSE,
        date_graded = NOW()
    WHERE id = v_existing_rating_id
    RETURNING id INTO v_rating_id;
    RAISE NOTICE 'Updated rating_id: %', v_rating_id;
  ELSE
    RAISE NOTICE 'Inserting new rating';
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
    RAISE NOTICE 'Inserted rating_id: %', v_rating_id;
  END IF;

  RAISE NOTICE 'Rating operation complete';

  -- Return success result
  v_result := json_build_object(
    'success', true,
    'song_id', v_song_id,
    'rating_id', v_rating_id
  );

  RAISE NOTICE 'Returning result';
  RETURN v_result;
END;
$$;
