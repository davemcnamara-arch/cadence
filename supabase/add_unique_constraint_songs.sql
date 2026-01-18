-- Add unique constraint to prevent duplicate songs
-- A song is considered unique by: title + artist + instrument_id
-- This allows the same song to exist for different instruments

-- First, remove any existing duplicates (run remove_duplicate_songs.sql first if needed)

-- Add unique constraint
ALTER TABLE songs
ADD CONSTRAINT songs_title_artist_instrument_unique
UNIQUE (title, artist, instrument_id);

-- Now ON CONFLICT DO NOTHING in INSERT statements will work properly
