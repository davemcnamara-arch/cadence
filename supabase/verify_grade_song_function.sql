-- Verify that the grade_song function exists
-- Run this in Supabase SQL Editor to check if the migration was applied

-- Check if function exists
SELECT
  p.proname as function_name,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_function_result(p.oid) as return_type,
  p.prosecdef as is_security_definer
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname = 'grade_song';

-- If the above query returns no rows, the function doesn't exist yet
-- You need to run the migration: supabase/migrations/014_add_grade_song_function.sql
