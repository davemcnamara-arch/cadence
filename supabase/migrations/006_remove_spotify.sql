-- Remove spotify_url column from songs table
-- We're only using YouTube for song links

ALTER TABLE songs
DROP COLUMN IF EXISTS spotify_url;
