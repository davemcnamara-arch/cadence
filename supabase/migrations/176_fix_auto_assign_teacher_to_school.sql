-- ============================================================
-- MIGRATION 176: Remove auto-assign-to-first-school from trigger
--
-- Bug: auto_assign_teacher_to_school() assigned new teachers to the
-- oldest school in the database when they created their first class
-- and held a school-plan trial (not an individual subscription).
-- Migration 170 changed the auto-trial default to 'school', so the
-- individual-subscription guard in migration 104 no longer protected
-- anyone — every new teacher with a school trial who created a class
-- was silently added to Mount Carmel College (the oldest school).
--
-- Fix: gut the function to a no-op. Teachers join schools explicitly
-- via join code or the school invite flow. The BEFORE INSERT trigger
-- (trg_set_class_school_id) already sets classes.school_id correctly
-- from the teacher's existing school membership; no fallback is needed.
-- ============================================================

CREATE OR REPLACE FUNCTION auto_assign_teacher_to_school()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN NEW;
END;
$$;
