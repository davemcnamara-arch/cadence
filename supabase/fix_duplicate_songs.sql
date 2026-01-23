-- Quick fix for duplicate songs
-- Run this in Supabase SQL Editor

-- Step 1: View the duplicates first (to verify)
SELECT
  title,
  artist,
  id,
  chords_url,
  tutorial_url,
  youtube_url,
  created_at
FROM songs
WHERE (title, artist) IN (
  SELECT title, artist
  FROM songs
  GROUP BY title, artist
  HAVING COUNT(*) > 1
)
ORDER BY title, artist, created_at DESC;

-- Step 2: Remove duplicates, keeping the one with links or most recent
WITH duplicates AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY title, artist
      ORDER BY
        CASE
          WHEN chords_url IS NOT NULL OR tutorial_url IS NOT NULL OR youtube_url IS NOT NULL THEN 0
          ELSE 1
        END,
        created_at DESC
    ) as rn
  FROM songs
),
ids_to_delete AS (
  SELECT id FROM duplicates WHERE rn > 1
)
-- Delete related data first
DELETE FROM song_ratings WHERE song_id IN (SELECT id FROM ids_to_delete);

WITH duplicates AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY title, artist
      ORDER BY
        CASE
          WHEN chords_url IS NOT NULL OR tutorial_url IS NOT NULL OR youtube_url IS NOT NULL THEN 0
          ELSE 1
        END,
        created_at DESC
    ) as rn
  FROM songs
),
ids_to_delete AS (
  SELECT id FROM duplicates WHERE rn > 1
)
DELETE FROM student_songs WHERE song_id IN (SELECT id FROM ids_to_delete);

WITH duplicates AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY title, artist
      ORDER BY
        CASE
          WHEN chords_url IS NOT NULL OR tutorial_url IS NOT NULL OR youtube_url IS NOT NULL THEN 0
          ELSE 1
        END,
        created_at DESC
    ) as rn
  FROM songs
),
ids_to_delete AS (
  SELECT id FROM duplicates WHERE rn > 1
)
DELETE FROM pending_links WHERE song_id IN (SELECT id FROM ids_to_delete);

-- Now delete the duplicate songs
WITH duplicates AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY title, artist
      ORDER BY
        CASE
          WHEN chords_url IS NOT NULL OR tutorial_url IS NOT NULL OR youtube_url IS NOT NULL THEN 0
          ELSE 1
        END,
        created_at DESC
    ) as rn
  FROM songs
)
DELETE FROM songs WHERE id IN (
  SELECT id FROM duplicates WHERE rn > 1
);

-- Step 3: Add unique constraint to prevent future duplicates
ALTER TABLE songs ADD CONSTRAINT unique_song_title_artist
  UNIQUE (title, artist);

-- Step 4: Verify no duplicates remain
SELECT
  title,
  artist,
  COUNT(*) as count
FROM songs
GROUP BY title, artist
HAVING COUNT(*) > 1;
-- This should return no rows
