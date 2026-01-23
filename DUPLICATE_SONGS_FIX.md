# Duplicate Songs Fix

## Problem Identified

The duplicate songs you're seeing are **NOT a bug in the code** - they're a **data integrity issue** in your database. The same songs exist multiple times with different database IDs:

**Found Duplicates:**
- "Hallelujah" by Leonard Cohen - 2 separate entries
- "Let It Be" by The Beatles - 2 separate entries
- "Someone Like You" by Adele - 2 separate entries

This likely happened during initial data imports or testing when songs were added multiple times.

## How to Fix

You have two options:

### Option 1: Run SQL Script Manually (Recommended)

1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Copy and paste the contents of `supabase/fix_duplicate_songs.sql`
4. Click **Run**
5. Verify the last query returns 0 rows (meaning no duplicates remain)

### Option 2: Apply Migration

If you're using Supabase CLI or a migration system:

```bash
psql <your-database-url> -f supabase/migrations/021_remove_duplicate_songs.sql
```

## What the Fix Does

1. **Finds duplicates** - Identifies all songs with the same title AND artist
2. **Keeps the best version** - Prioritizes:
   - Songs that have resource links (chords_url, tutorial_url, youtube_url)
   - If none have links, keeps the most recently created one
3. **Cleans up related data** - Removes ratings, student_songs, and pending_links for duplicates
4. **Deletes duplicates** - Removes the duplicate song entries
5. **Prevents future duplicates** - Adds a UNIQUE constraint on (title, artist)

## After Running the Fix

- Duplicates will be completely gone
- Each song will appear only once
- The UNIQUE constraint ensures no new duplicates can be created
- If someone tries to add a song that already exists, they'll get a database error

## Verification

After running the script, refresh your app and search for "Let It Be" - you should see only ONE result instead of two!

The console logs will also stop showing the `⚠️ DUPLICATES BY TITLE/ARTIST` warnings.

## Prevention Going Forward

With the UNIQUE constraint in place, if you try to add a song that already exists (same title + artist), you'll get a database error. This is intentional - it prevents duplicates from being created.

If you want to allow re-adding songs (perhaps for different arrangements or versions), you'll need to:
1. Use a different title (e.g., "Let It Be (Acoustic)" vs "Let It Be")
2. Or modify the constraint to include additional fields like `arrangement` or `version`
