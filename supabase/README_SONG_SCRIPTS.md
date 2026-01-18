# Song Database Scripts - Quick Reference

This document explains the three SQL scripts for managing song duplicates and preventing them in the future.

## The Problem

When song population scripts are run multiple times, or when multiple scripts add the same songs, you can end up with duplicate entries. This causes:
- Multiple cards showing for the same song
- Confusion about which version to use
- Cluttered song library

## The Solution

Three scripts work together to solve this:

### 1. `add_unique_constraint_songs.sql` - Prevent Future Duplicates

**Purpose:** Adds a database constraint that prevents the same song (title + artist + instrument) from being inserted twice.

**When to run:**
- **Once**, before populating songs for the first time
- Or after cleaning up existing duplicates

**What it does:**
- Adds a UNIQUE constraint on (title, artist, instrument_id)
- Makes `ON CONFLICT DO NOTHING` in INSERT statements actually work
- Prevents accidental duplicates going forward

**Run this:** In Supabase SQL Editor

```sql
-- Copy and run: add_unique_constraint_songs.sql
```

### 2. `remove_duplicate_songs.sql` - Clean Up Existing Duplicates

**Purpose:** Removes duplicate songs that already exist in your database.

**When to run:**
- If you've already run song population scripts and have duplicates
- Before adding the unique constraint
- Anytime you notice duplicate songs

**What it does:**
- Finds all songs with the same (title, artist, instrument_id)
- Keeps the first one (by date_added)
- Deletes all other duplicates
- Shows a summary of remaining songs by instrument

**Run this:** In Supabase SQL Editor

```sql
-- Copy and run: remove_duplicate_songs.sql
```

### 3. `populate_all_levels.sql` - Add Songs for All Levels

**Purpose:** Populates the song library with songs for all instruments at levels 4-5.

**When to run:**
- After running the unique constraint script
- After cleaning up duplicates (if any existed)

**What it does:**
- Adds 50+ carefully selected songs
- Covers all 5 instruments at levels 4-5
- Skips songs that already exist (thanks to unique constraint)
- Each song includes YouTube URL

**Run this:** In Supabase SQL Editor

```sql
-- Copy and run: populate_all_levels.sql
```

## Recommended Workflow

### If You're Starting Fresh

1. Run `add_unique_constraint_songs.sql`
2. Run `populate_all_levels.sql`
3. Done!

### If You Already Have Duplicate Songs

1. Run `remove_duplicate_songs.sql` (cleans up existing duplicates)
2. Run `add_unique_constraint_songs.sql` (prevents future duplicates)
3. Run `populate_all_levels.sql` (adds missing songs)
4. Done!

## How to Check for Duplicates

Run this query in Supabase SQL Editor:

```sql
SELECT
  title,
  artist,
  i.name as instrument,
  COUNT(*) as duplicate_count
FROM songs s
JOIN instruments i ON s.instrument_id = i.id
GROUP BY title, artist, i.name
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, title;
```

If this returns no rows, you have no duplicates! ✅

## Notes

- The unique constraint allows the same song to exist for **different instruments** (e.g., "Come Together" for both Bass and Drums)
- Running `populate_all_levels.sql` multiple times is safe after the unique constraint is added
- Chord/tab URLs should be added manually through the app's UI
- All songs are auto-approved and include YouTube URLs

## Troubleshooting

**Error: "duplicate key value violates unique constraint"**
- This means you're trying to insert a song that already exists
- This is actually good! The constraint is working
- The `ON CONFLICT DO NOTHING` should handle this gracefully

**I see the same song twice**
- Run `remove_duplicate_songs.sql` to clean up
- Check that you have the unique constraint added
- Make sure you're not looking at the same song for different instruments

**A song is missing after cleanup**
- Check which version was kept (the first by date_added)
- You can manually re-add the song if needed
- Consider adding it through the app's "Grade New Song" feature
