-- Remove non-Ultimate Guitar chord links
-- Only keep chords from tabs.ultimate-guitar.com as other sites have inaccurate content
-- (wrong songs, incorrect tabs, etc.)

-- Clear chord links that are not from Ultimate Guitar
UPDATE songs
SET chords_url = NULL
WHERE chords_url IS NOT NULL
  AND chords_url NOT LIKE '%tabs.ultimate-guitar.com%';

-- Songs affected by this cleanup (if they had non-UG links):
-- - Piano songs: Imagine (pianote.com), Lean on Me (musicnotes.com), Clocks (musicnotes.com)
-- - Drums songs: We Will Rock You (songsterr.com)
-- - Any other songs with links to: goodguitarist.com, justinguitar.com, sixstringfingerpicking.com,
--   pianote.com, musicnotes.com, hdpiano.com, songsterr.com, or other non-UG sites

-- After running this, users can add their own accurate Ultimate Guitar links
-- using the "Add" buttons in the UI
