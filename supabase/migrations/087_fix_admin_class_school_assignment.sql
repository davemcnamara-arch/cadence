-- ============================================================
-- MIGRATION 087: Fix class school assignment for admin users
--
-- Problem: Migration 083 removed all admins from school_members
-- to block them from appearing as school teachers. This broke
-- the BEFORE INSERT trigger set_class_school_id, which looks
-- up school_members to set school_id on new classes — so all
-- classes created by admins after migration 083 have school_id = NULL.
--
-- Fix:
--   1. Update set_class_school_id to fall back to looking at
--      existing classes the admin already has a school_id on,
--      OR the first school the admin created.
--   2. The school picker in the Create Class UI is the primary
--      mechanism — this trigger is just the fallback.
-- ============================================================

CREATE OR REPLACE FUNCTION set_class_school_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_school_id UUID;
BEGIN
  -- If school_id was explicitly passed in (from the UI picker), use it
  IF NEW.school_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- For teachers: use their earliest-joined school
  SELECT sm.school_id INTO v_school_id
  FROM school_members sm
  WHERE sm.user_id = NEW.teacher_id
  ORDER BY sm.joined_at ASC
  LIMIT 1;

  IF v_school_id IS NOT NULL THEN
    NEW.school_id := v_school_id;
    RETURN NEW;
  END IF;

  -- For admins (not in school_members): use the school they created,
  -- or fall back to the most common school_id among their existing classes
  SELECT school_id INTO v_school_id
  FROM schools
  WHERE created_by = NEW.teacher_id
  ORDER BY created_at ASC
  LIMIT 1;

  IF v_school_id IS NOT NULL THEN
    NEW.school_id := v_school_id;
    RETURN NEW;
  END IF;

  -- Last resort: pick the school_id most used by this teacher's existing classes
  SELECT school_id INTO v_school_id
  FROM classes
  WHERE teacher_id = NEW.teacher_id
    AND school_id IS NOT NULL
  GROUP BY school_id
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  IF v_school_id IS NOT NULL THEN
    NEW.school_id := v_school_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_class_school_id ON classes;
CREATE TRIGGER trg_set_class_school_id
  BEFORE INSERT ON classes
  FOR EACH ROW
  EXECUTE FUNCTION set_class_school_id();

GRANT EXECUTE ON FUNCTION set_class_school_id() TO authenticated;
