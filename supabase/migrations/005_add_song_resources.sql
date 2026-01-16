-- Add columns for chord charts and tutorial videos

ALTER TABLE songs
ADD COLUMN chords_url TEXT,
ADD COLUMN tutorial_url TEXT;
