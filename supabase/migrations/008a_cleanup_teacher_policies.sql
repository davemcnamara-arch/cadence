-- Cleanup script: Drop all existing teacher modification policies
-- Run this FIRST if you encounter "policy already exists" errors

DO $$
BEGIN
    -- Drop student_progress policies
    DROP POLICY IF EXISTS "Teachers can view student progress" ON student_progress;
    DROP POLICY IF EXISTS "Teachers can insert student progress" ON student_progress;
    DROP POLICY IF EXISTS "Teachers can update student progress" ON student_progress;
    DROP POLICY IF EXISTS "Teachers can delete student progress" ON student_progress;

    -- Drop student_songs policies
    DROP POLICY IF EXISTS "Teachers can view student songs" ON student_songs;
    DROP POLICY IF EXISTS "Teachers can insert student songs" ON student_songs;
    DROP POLICY IF EXISTS "Teachers can update student songs" ON student_songs;
    DROP POLICY IF EXISTS "Teachers can delete student songs" ON student_songs;

    -- Drop song_ratings policies
    DROP POLICY IF EXISTS "Teachers can view student ratings" ON song_ratings;
    DROP POLICY IF EXISTS "Teachers can insert student ratings" ON song_ratings;
    DROP POLICY IF EXISTS "Teachers can update student ratings" ON song_ratings;
    DROP POLICY IF EXISTS "Teachers can delete student ratings" ON song_ratings;

    -- Drop resource_ratings policies
    DROP POLICY IF EXISTS "Teachers can view student resource ratings" ON resource_ratings;
    DROP POLICY IF EXISTS "Teachers can insert student resource ratings" ON resource_ratings;
    DROP POLICY IF EXISTS "Teachers can update student resource ratings" ON resource_ratings;
    DROP POLICY IF EXISTS "Teachers can delete student resource ratings" ON resource_ratings;

    RAISE NOTICE 'All teacher modification policies have been dropped successfully';
END $$;
