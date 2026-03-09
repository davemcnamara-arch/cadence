-- ============================================================
-- MIGRATION 085: Deduplicate classes
--
-- Problem: Double-clicking the "Create Class" button could
-- submit the form twice, creating two identical classes
-- (same name / teacher_id, different id / class_code).
-- This migration removes the newer duplicate keeping the
-- oldest class per (teacher_id, name) group, and cleans up
-- orphaned class_members and pending_enrollments rows.
-- ============================================================

-- ============================================================
-- 1. Diagnostic: show duplicate (teacher_id, name) pairs
--    before cleanup (useful for manual review)
-- ============================================================
-- SELECT teacher_id, name, COUNT(*) AS cnt,
--        array_agg(id ORDER BY created_at ASC) AS class_ids
-- FROM classes
-- WHERE archived = false
-- GROUP BY teacher_id, name
-- HAVING COUNT(*) > 1;

-- ============================================================
-- 2. Delete class_members rows belonging to duplicate classes
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
-- 3. Delete pending_enrollments for duplicate classes
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
-- 4. Delete the duplicate class rows themselves
-- ============================================================
DELETE FROM classes
WHERE id NOT IN (
  SELECT DISTINCT ON (teacher_id, name) id
  FROM classes
  ORDER BY teacher_id, name, created_at ASC
);
