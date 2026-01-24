-- Add teacher_reviewed flag to song_ratings for new grading flow
ALTER TABLE song_ratings
ADD COLUMN IF NOT EXISTS teacher_reviewed BOOLEAN DEFAULT FALSE;

-- Mark existing ratings as already reviewed (so they don't suddenly appear in flagged tab)
UPDATE song_ratings
SET teacher_reviewed = TRUE
WHERE teacher_reviewed IS NULL OR teacher_reviewed = FALSE;

-- New ratings will default to FALSE and appear in the flagged tab for review
