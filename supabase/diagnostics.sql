-- Diagnostic query to check song_ratings table structure
-- Run this first to see what's wrong

-- 1. Check if teacher_reviewed column exists
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'song_ratings'
ORDER BY ordinal_position;

-- 2. Check current grade_song function signature
SELECT routine_name, routine_definition
FROM information_schema.routines
WHERE routine_name = 'grade_song'
  AND routine_schema = 'public';

-- 3. Try a simple test insert to see what fails
-- (This won't actually insert because we'll use a non-existent user)
-- Look at the error message to understand what's failing
