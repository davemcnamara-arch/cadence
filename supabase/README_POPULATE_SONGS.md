# Populating Song Library - All Instruments and Levels

This document explains how to populate the Cadence song library with songs for all instruments at all levels (1-5).

## What's Been Added

The `populate_all_levels.sql` script adds songs for:

- **Guitar**: Levels 4 and 5 (Levels 1-3 already existed)
- **Bass Guitar**: Levels 4 and 5 (Levels 1-3 already existed)
- **Piano/Keyboard**: Levels 4 and 5 (Levels 1-3 already existed)
- **Drums**: Levels 4 and 5 (Levels 1-3 already existed)
- **Vocals**: Levels 4 and 5 (Levels 1-3 already existed)

## Song Coverage

After running this script, you will have:

### Guitar
- **Level 1**: 5 songs (Foundation - basic chords)
- **Level 2**: 3 songs (Expanding Vocabulary)
- **Level 3**: 4 songs (Technical Development)
- **Level 4**: 9+ songs (Rhythm/Fingerstyle/Lead Focus)
- **Level 5**: 5 songs (Advanced techniques - Rhythm/Fingerstyle/Lead)

### Bass Guitar
- **Level 1**: 4 songs (Foundation)
- **Level 2**: 3 songs (Rhythm Development)
- **Level 3**: 3 songs (Melodic Playing)
- **Level 4**: 5 songs (Groove/Melodic/Rock Focus)
- **Level 5**: 5 songs (Slap/Pop, Jazz/Walking, Modern Rock)

### Piano/Keyboard
- **Level 1**: 3 songs (Foundation)
- **Level 2**: 2 songs (Coordination Development)
- **Level 3**: 4 songs (Independence Building)
- **Level 4**: 6 songs (Contemporary/Pop, Singer-Songwriter, Jazz/Blues)
- **Level 5**: 6 songs (Extended Chords, Performance Skills, Improvisation)

### Drums
- **Level 1**: 3 songs (Foundation)
- **Level 2**: 3 songs (Pattern Development)
- **Level 3**: 3 songs (Coordination & Fills)
- **Level 4**: 6 songs (Rock/Pop, Funk/R&B, Punk/Alternative)
- **Level 5**: 6 songs (Progressive/Complex, Jazz/Swing, Double Bass/Metal)

### Vocals
- **Level 1**: 2 songs (Foundation)
- **Level 2**: 3 songs (Range Development)
- **Level 3**: 3 songs (Technique Building)
- **Level 4**: 6 songs (Pop/Contemporary, Singer-Songwriter, Soul/R&B)
- **Level 5**: 6 songs (Powerful Vocals, Nuanced Performance, Improvisation)

## How to Run This Script

### Method 1: Supabase SQL Editor (Recommended)

1. Go to your Supabase project dashboard
2. Click on **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the entire contents of `supabase/populate_all_levels.sql`
5. Paste into the SQL editor
6. Click **Run** (bottom right)
7. Wait for confirmation: "Success. No rows returned"

### Method 2: Supabase CLI (If you have it installed)

```bash
# Make sure you're logged in to Supabase
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_ID

# Run the SQL file
supabase db execute -f supabase/populate_all_levels.sql
```

## Verification

After running the script, verify that songs were added:

1. Go to **Table Editor** in Supabase
2. Click on the `songs` table
3. You should now see songs for all 5 instruments across all 5 levels

Or test in the app:

1. Sign in to Cadence
2. Go to **Song Library** tab
3. Use the filters to check each instrument and level
4. You should see at least one song for every combination

## Notes

- All songs include YouTube URLs for reference
- Chord/tab links (chords_url field) are left empty and can be added manually through the app
- Songs are automatically marked as `approved = true`
- The script uses `ON CONFLICT DO NOTHING` to avoid duplicates
- Each song is matched to the appropriate level based on the skill requirements defined in `seed.sql`
- Users can easily add chord links by clicking the "+ Chords" button on each song card in the app

## Song Selection Criteria

Songs were selected to match the level descriptions:

- **Level 4**: Advanced techniques specific to each branch (Rhythm/Fingerstyle/Lead, etc.)
- **Level 5**: Mastery-level songs requiring professional technique and interpretation

All songs are well-known, have readily available learning resources, and represent the target skill level appropriately.
