-- Find and remove duplicate songs (same title + artist, different IDs)
-- Keep the song with links if one has them, otherwise keep the most recent

-- First, let's see what duplicates we have
-- This query will show all duplicate songs
WITH duplicate_songs AS (
  SELECT
    title,
    artist,
    COUNT(*) as count,
    ARRAY_AGG(id ORDER BY
      CASE
        WHEN chords_url IS NOT NULL OR tutorial_url IS NOT NULL OR youtube_url IS NOT NULL THEN 0
        ELSE 1
      END,
      created_at DESC
    ) as ids
  FROM songs
  GROUP BY title, artist
  HAVING COUNT(*) > 1
)
SELECT * FROM duplicate_songs;

-- For each duplicate group, keep the first ID (the one with links or most recent)
-- and delete the others
DO $$
DECLARE
  dup RECORD;
  keep_id UUID;
  delete_ids UUID[];
BEGIN
  FOR dup IN
    SELECT
      title,
      artist,
      ARRAY_AGG(id ORDER BY
        CASE
          WHEN chords_url IS NOT NULL OR tutorial_url IS NOT NULL OR youtube_url IS NOT NULL THEN 0
          ELSE 1
        END,
        created_at DESC
      ) as ids
    FROM songs
    GROUP BY title, artist
    HAVING COUNT(*) > 1
  LOOP
    -- Keep the first ID (has links or most recent)
    keep_id := dup.ids[1];

    -- Get all IDs to delete (everything except the first)
    delete_ids := dup.ids[2:array_length(dup.ids, 1)];

    RAISE NOTICE 'Keeping song "%" by "%" with ID %, deleting %',
      dup.title, dup.artist, keep_id, delete_ids;

    -- Delete related data first (to avoid foreign key issues)
    DELETE FROM song_ratings WHERE song_id = ANY(delete_ids);
    DELETE FROM student_songs WHERE song_id = ANY(delete_ids);
    DELETE FROM pending_links WHERE song_id = ANY(delete_ids);

    -- Now delete the duplicate songs
    DELETE FROM songs WHERE id = ANY(delete_ids);
  END LOOP;
END $$;

-- Add a unique constraint to prevent future duplicates
-- This ensures no two songs can have the same title AND artist
ALTER TABLE songs ADD CONSTRAINT unique_song_title_artist
  UNIQUE (title, artist);

-- Verify the cleanup
SELECT
  title,
  artist,
  COUNT(*) as count
FROM songs
GROUP BY title, artist
HAVING COUNT(*) > 1;
-- This should return no rows if successful
