-- ============================================================
-- MIGRATION 085: Deduplicate classes
--
-- Problem: Double-clicking the "Create Class" button could
-- submit the form twice, creating two identical classes
-- (same name / teacher_id, different id / class_code).
-- This migration removes the newer duplicate keeping the
-- oldest class per (teacher_id, name) group, and cleans up
-- orphaned class_members and pending_enrollments rows.
--
-- HOW TO APPLY:
--   Paste this entire file into your Supabase SQL Editor and run it.
--
-- STEP 0 (optional diagnostic — run this alone first to preview):
-- ============================================================
-- SELECT
--   u.name AS teacher,
--   c.name AS class_name,
--   COUNT(*) AS duplicate_count,
--   array_agg(c.id ORDER BY c.created_at ASC) AS class_ids,
--   array_agg(c.class_code ORDER BY c.created_at ASC) AS class_codes,
--   array_agg(c.created_at ORDER BY c.created_at ASC) AS created_ats
-- FROM classes c
-- JOIN users u ON u.id = c.teacher_id
-- GROUP BY u.name, c.name
-- HAVING COUNT(*) > 1
-- ORDER BY u.name, c.name;
-- ============================================================

-- ============================================================
-- 1. Delete class_members rows belonging to duplicate classes
--    (keeps members of the oldest class, drops the rest)
-- ============================================================
DELETE FROM class_members
WHERE class_id IN (
  SELECT id FROM classes c
  WHERE c.id NOT IN (
    -- Keep the oldest class per (teacher_id, name)
    SELECT DISTINCT ON (teacher_id, name) id
    FROM classes
    ORDER BY teacher_id, name, created_at ASC
  )
);

-- ============================================================
-- 2. Delete pending_enrollments for duplicate classes
-- ============================================================
DELETE FROM pending_enrollments
WHERE class_id IN (
  SELECT id FROM classes c
  WHERE c.id NOT IN (
    SELECT DISTINCT ON (teacher_id, name) id
    FROM classes
    ORDER BY teacher_id, name, created_at ASC
  )
);

-- ============================================================
-- 3. Delete the duplicate class rows themselves
-- ============================================================
DELETE FROM classes
WHERE id NOT IN (
  SELECT DISTINCT ON (teacher_id, name) id
  FROM classes
  ORDER BY teacher_id, name, created_at ASC
);
