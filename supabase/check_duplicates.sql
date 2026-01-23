-- Check for duplicate songs in database
SELECT
  title,
  artist,
  id,
  chords_url,
  tutorial_url,
  youtube_url,
  approved,
  created_at,
  date_added
FROM songs
WHERE (title, artist) IN (
  SELECT title, artist
  FROM songs
  WHERE approved = true
  GROUP BY title, artist
  HAVING COUNT(*) > 1
)
ORDER BY title, artist, created_at;

-- Summary of duplicates
SELECT
  title,
  artist,
  COUNT(*) as duplicate_count
FROM songs
WHERE approved = true
GROUP BY title, artist
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, title;
