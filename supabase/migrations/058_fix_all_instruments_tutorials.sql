-- Migration: Pin "All Instruments" tutorials to their correct instrument
--
-- Migration 056 copied songs.tutorial_url into song_tutorials with instrument_id
-- determined from song_ratings. If a song had ratings for multiple instruments (or
-- zero), instrument_id was set to NULL, making the tutorial show as "All Instruments".
--
-- Since songs.tutorial_url gets overwritten on each grading, the value that was
-- migrated corresponds to the MOST RECENT grading. This migration pins those NULL
-- tutorials to the instrument from the most recent song_rating by the same user who
-- submitted the tutorial (i.e. the teacher who last graded it). If there is no
-- matching user, it falls back to the most recent song_rating for the song overall.
--
-- This also fixes any student_resources that have NULL instrument_id by using the
-- same heuristic.

-- ==============================================
-- FIX song_tutorials with NULL instrument_id
-- ==============================================

-- Step 1: Try to match by same submitter (the teacher who graded the song)
UPDATE song_tutorials st
SET instrument_id = (
  SELECT sr.instrument_id
  FROM song_ratings sr
  WHERE sr.song_id = st.song_id
    AND sr.user_id = st.submitted_by_user_id
  ORDER BY sr.date_graded DESC
  LIMIT 1
)
WHERE st.instrument_id IS NULL
  AND st.submitted_by_user_id IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM song_ratings sr
    WHERE sr.song_id = st.song_id
      AND sr.user_id = st.submitted_by_user_id
  );

-- Step 2: For any remaining NULLs, fall back to most recent song_rating for the song
UPDATE song_tutorials st
SET instrument_id = (
  SELECT sr.instrument_id
  FROM song_ratings sr
  WHERE sr.song_id = st.song_id
  ORDER BY sr.date_graded DESC
  LIMIT 1
)
WHERE st.instrument_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM song_ratings sr
    WHERE sr.song_id = st.song_id
  );

-- ==============================================
-- FIX student_resources with NULL instrument_id
-- ==============================================

-- Step 1: Try to match by same user's song_ratings
UPDATE student_resources sres
SET instrument_id = (
  SELECT sr.instrument_id
  FROM song_ratings sr
  WHERE sr.song_id = sres.song_id
    AND sr.user_id = sres.user_id
  ORDER BY sr.date_graded DESC
  LIMIT 1
)
WHERE sres.instrument_id IS NULL
  AND sres.user_id IS NOT NULL
  AND EXISTS (
    SELECT 1
    FROM song_ratings sr
    WHERE sr.song_id = sres.song_id
      AND sr.user_id = sres.user_id
  );

-- Step 2: For any remaining NULLs, fall back to most recent song_rating for the song
UPDATE student_resources sres
SET instrument_id = (
  SELECT sr.instrument_id
  FROM song_ratings sr
  WHERE sr.song_id = sres.song_id
  ORDER BY sr.date_graded DESC
  LIMIT 1
)
WHERE sres.instrument_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM song_ratings sr
    WHERE sr.song_id = sres.song_id
  );
