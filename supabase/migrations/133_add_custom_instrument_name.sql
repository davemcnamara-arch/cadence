-- Add custom_instrument_name to student_progress so students using "Other Instrument"
-- can specify what they actually play (e.g. "Violin", "Clarinet").
--
-- Because a student can have multiple "Other" instruments (e.g. both violin and clarinet),
-- the old UNIQUE(user_id, instrument_id) constraint must be replaced with two partial
-- unique indexes:
--   • Standard instruments: still unique per (user_id, instrument_id)
--   • Other instruments: unique per (user_id, instrument_id, custom_instrument_name)

ALTER TABLE student_progress
  ADD COLUMN custom_instrument_name TEXT;

-- Drop the old single-column unique constraint
ALTER TABLE student_progress
  DROP CONSTRAINT student_progress_user_id_instrument_id_key;

-- Standard instruments (no custom name): one row per instrument per student
CREATE UNIQUE INDEX student_progress_standard_unique
  ON student_progress (user_id, instrument_id)
  WHERE custom_instrument_name IS NULL;

-- Other instruments (with custom name): one row per named instrument per student
CREATE UNIQUE INDEX student_progress_other_unique
  ON student_progress (user_id, instrument_id, custom_instrument_name)
  WHERE custom_instrument_name IS NOT NULL;
