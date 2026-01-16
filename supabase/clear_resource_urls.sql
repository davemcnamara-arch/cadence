-- Clear Spotify, chords, and tutorial URLs from songs
-- This leaves the columns available for users to add their own resources later

UPDATE songs
SET spotify_url = NULL,
    chords_url = NULL,
    tutorial_url = NULL;
