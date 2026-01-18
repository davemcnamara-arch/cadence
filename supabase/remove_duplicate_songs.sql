-- Remove Duplicate Songs Script
-- This script removes duplicate song entries, keeping only the first occurrence (by date_added)

-- First, let's see what duplicates we have (for reference)
-- This query finds songs with the same title, artist, and instrument_id
WITH duplicates AS (
  SELECT
    id,
    title,
    artist,
    instrument_id,
    suggested_level,
    date_added,
    ROW_NUMBER() OVER (
      PARTITION BY title, artist, instrument_id
      ORDER BY date_added ASC
    ) as row_num
  FROM songs
)
-- Delete all duplicates except the first one
DELETE FROM songs
WHERE id IN (
  SELECT id
  FROM duplicates
  WHERE row_num > 1
);

-- Display how many songs remain
SELECT
  i.name as instrument,
  COUNT(*) as song_count
FROM songs s
JOIN instruments i ON s.instrument_id = i.id
GROUP BY i.name
ORDER BY i.name;
