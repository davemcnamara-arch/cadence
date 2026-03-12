-- ============================================================
-- MIGRATION 104: Fix individual teacher auto-school assignment
--
-- Problem: auto_assign_teacher_to_school() was assigning
-- individual teachers to the first school in the system when
-- they created their first class. Individual teachers should
-- have no school affiliation.
--
-- Fix: Skip auto-assignment if the teacher has an individual
-- subscription (plan_type = 'individual').
-- ============================================================

CREATE OR REPLACE FUNCTION auto_assign_teacher_to_school()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_role TEXT;
  v_school_id UUID;
BEGIN
  -- Only act on teacher/admin users
  SELECT role INTO v_teacher_role FROM users WHERE id = NEW.teacher_id;
  IF v_teacher_role NOT IN ('teacher', 'admin') THEN
    RETURN NEW;
  END IF;

  -- Skip if teacher is already in a school (BEFORE trigger handles school_id)
  IF EXISTS (SELECT 1 FROM school_members WHERE user_id = NEW.teacher_id) THEN
    RETURN NEW;
  END IF;

  -- Skip if teacher has an individual subscription — they are not school-affiliated
  IF EXISTS (
    SELECT 1 FROM subscriptions
    WHERE teacher_id = NEW.teacher_id
      AND plan_type = 'individual'
  ) THEN
    RETURN NEW;
  END IF;

  -- Find the first school in the system
  SELECT id INTO v_school_id FROM schools ORDER BY created_at ASC LIMIT 1;
  IF v_school_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Add teacher to school
  INSERT INTO school_members (school_id, user_id, school_role)
  VALUES (v_school_id, NEW.teacher_id, v_teacher_role)
  ON CONFLICT (school_id, user_id) DO NOTHING;

  -- Back-set school_id on the class that was just created
  -- (BEFORE trigger ran when teacher had no school yet, so school_id was NULL)
  IF NEW.school_id IS NULL THEN
    UPDATE classes SET school_id = v_school_id WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;
