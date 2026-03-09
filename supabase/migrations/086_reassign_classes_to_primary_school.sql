-- ============================================================
-- MIGRATION 086: Reassign classes to teacher's primary school
--
-- Problem: Classes created after a teacher joined a second school
-- got school_id assigned to the wrong school (whichever was
-- "earliest" at insertion time), causing classes to be split
-- across schools in dashboards.
--
-- Fix: Re-assign every class to its teacher's earliest-joined
-- school (their "primary" school), so all pre-existing classes
-- belong to one school.
--
-- This does NOT affect new classes — the BEFORE INSERT trigger
-- (set_class_school_id) will now use the explicit school_id
-- passed from the UI, so teachers can choose which school a
-- new class belongs to.
-- ============================================================

UPDATE classes c
SET school_id = subq.primary_school_id
FROM (
  -- Each teacher's earliest-joined school
  SELECT DISTINCT ON (user_id)
    user_id,
    school_id AS primary_school_id
  FROM school_members
  ORDER BY user_id, joined_at ASC
) subq
WHERE c.teacher_id = subq.user_id
  AND (c.school_id IS NULL OR c.school_id IS DISTINCT FROM subq.primary_school_id);
