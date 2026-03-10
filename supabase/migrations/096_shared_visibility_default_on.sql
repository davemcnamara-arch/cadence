-- ============================================================
-- MIGRATION 096: Default shared class visibility to ON
--
-- Shared class visibility should be on by default so all
-- teachers in a school can see and edit each other's classes
-- without any manual setup. Admins can still disable it per
-- school if needed.
--
-- Changes:
--   1. Backfill all existing schools to shared_class_visibility = TRUE
--   2. Change the column default to TRUE for new schools
-- ============================================================

-- Backfill existing schools
UPDATE schools SET shared_class_visibility = TRUE WHERE shared_class_visibility = FALSE;

-- New schools default to on
ALTER TABLE schools
  ALTER COLUMN shared_class_visibility SET DEFAULT TRUE;
