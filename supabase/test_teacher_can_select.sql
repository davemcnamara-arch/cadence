-- Test if teacher can SELECT student's songs
-- Run this while logged in AS THE TEACHER

-- This simulates what happens when the app queries student_songs
SELECT
  id,
  user_id,
  song_id,
  instrument_id,
  status,
  date_started
FROM student_songs
WHERE user_id = '68e46010-9ca3-4c0a-97bf-b1fb835928cb'
LIMIT 5;

-- If this returns rows: ✓ SELECT works
-- If this returns 0 rows or 406 error: ✗ Policy blocking access

-- Also test: Can we see if a specific song exists?
SELECT
  COUNT(*) as song_count,
  CASE
    WHEN COUNT(*) > 0 THEN '✓ Can query student songs'
    ELSE 'No songs found (but query worked)'
  END as status
FROM student_songs
WHERE user_id = '68e46010-9ca3-4c0a-97bf-b1fb835928cb'
  AND song_id = 'f1aaf1da-47dd-47c7-817a-1dd5b29a3af6'
  AND instrument_id = 'b81e3ade-fcf2-44c3-8a02-21b1b547ddfd';
