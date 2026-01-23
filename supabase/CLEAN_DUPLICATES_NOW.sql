-- STEP 1: See what we're keeping vs deleting (review first)
WITH ranked_songs AS (
  SELECT
    id,
    title,
    artist,
    chords_url,
    tutorial_url,
    youtube_url,
    created_at,
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
  WHERE (title, artist) IN (
    SELECT title, artist
    FROM songs
    GROUP BY title, artist
    HAVING COUNT(*) > 1
  )
)
SELECT
  title,
  artist,
  CASE WHEN rn = 1 THEN 'KEEPING' ELSE 'DELETING' END as action,
  id,
  chords_url,
  tutorial_url,
  youtube_url,
  created_at
FROM ranked_songs
ORDER BY title, artist, rn;

-- STEP 2: Delete related data for duplicate songs
WITH ranked_songs AS (
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
  SELECT id FROM ranked_songs WHERE rn > 1
)
DELETE FROM song_ratings WHERE song_id IN (SELECT id FROM ids_to_delete);

WITH ranked_songs AS (
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
  SELECT id FROM ranked_songs WHERE rn > 1
)
DELETE FROM student_songs WHERE song_id IN (SELECT id FROM ids_to_delete);

WITH ranked_songs AS (
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
  SELECT id FROM ranked_songs WHERE rn > 1
)
DELETE FROM pending_links WHERE song_id IN (SELECT id FROM ids_to_delete);

-- STEP 3: Delete the duplicate songs (keeping the best version)
WITH ranked_songs AS (
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
  SELECT id FROM ranked_songs WHERE rn > 1
);

-- STEP 4: Add unique constraint to prevent future duplicates
-- Drop if exists first (in case you run this multiple times)
ALTER TABLE songs DROP CONSTRAINT IF EXISTS unique_song_title_artist;
ALTER TABLE songs ADD CONSTRAINT unique_song_title_artist UNIQUE (title, artist);

-- STEP 5: Verify cleanup
SELECT
  'Remaining duplicates:' as status,
  COUNT(*) as count
FROM (
  SELECT title, artist
  FROM songs
  GROUP BY title, artist
  HAVING COUNT(*) > 1
) subquery;
-- Should show 0

-- Show final song count
SELECT
  'Total approved songs:' as status,
  COUNT(*) as count
FROM songs
WHERE approved = true;
