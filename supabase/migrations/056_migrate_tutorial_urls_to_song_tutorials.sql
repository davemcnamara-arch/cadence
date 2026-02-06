-- Migration: Preserve existing songs.tutorial_url values in song_tutorials
--
-- The songs.tutorial_url field is a single column that gets overwritten each time
-- a song is graded for a different instrument. This migration copies any current
-- tutorial_url values into the song_tutorials table (with instrument_id where
-- possible) so they are not lost when the next grading overwrites the field.
--
-- Logic:
--   - For each song that has a tutorial_url not already present in song_tutorials,
--     insert it as an approved entry.
--   - If the song has been rated for exactly one instrument, assign that instrument_id
--     so the tutorial appears under the correct instrument filter.
--   - If the song has been rated for multiple (or zero) instruments, leave
--     instrument_id NULL (universal) so it appears under all instruments.

INSERT INTO song_tutorials (song_id, url, title, instrument_id, submitted_by_user_id, status, created_at)
SELECT
  s.id,
  s.tutorial_url,
  'Tutorial Video',
  -- Assign instrument_id only if the song has exactly one rated instrument
  CASE
    WHEN (SELECT COUNT(DISTINCT sr.instrument_id) FROM song_ratings sr WHERE sr.song_id = s.id) = 1
    THEN (SELECT DISTINCT sr.instrument_id FROM song_ratings sr WHERE sr.song_id = s.id LIMIT 1)
    ELSE NULL
  END,
  s.added_by_user_id,
  'approved',
  NOW()
FROM songs s
WHERE s.tutorial_url IS NOT NULL
  AND s.tutorial_url != ''
  -- Only insert if this exact URL is not already in song_tutorials for this song
  AND NOT EXISTS (
    SELECT 1 FROM song_tutorials st
    WHERE st.song_id = s.id
      AND st.url = s.tutorial_url
  );
