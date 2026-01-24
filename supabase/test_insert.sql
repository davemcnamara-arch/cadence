-- Test if we can insert directly into song_ratings (bypassing the function)
-- This will help us see if there's a trigger or RLS policy causing the hang

-- First, check what triggers exist on song_ratings
SELECT
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'song_ratings';

-- Check RLS policies on song_ratings
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'song_ratings';
