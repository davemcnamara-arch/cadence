-- =============================================================================
-- CADENCE DATA QUALITY CLEANUP
-- =============================================================================
-- How to use:
--   1. Run all PHASE 1 queries first (read-only — safe to run anytime).
--      Review the results carefully.
--   2. Once you are satisfied with what you see, run PHASE 2 (cleanup).
--      Destructive statements are clearly marked and commented out by default.
--      Uncomment them one section at a time and confirm before running.
--
-- Paste each section into the Supabase SQL editor (https://supabase.com/dashboard)
-- under your project → SQL Editor.
-- =============================================================================


-- =============================================================================
-- PHASE 1: INSPECTION (read-only)
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1A.  Classes with a blank or null name
--      Note: classes.name is defined NOT NULL in the schema, so these would
--      only exist if the constraint was dropped or bypassed via service-role.
--      Empty strings ('') are still possible within that constraint.
-- -----------------------------------------------------------------------------
SELECT
  c.id            AS class_id,
  c.class_code,
  c.name          AS class_name,
  u.name          AS teacher_name,
  u.email         AS teacher_email,
  c.created_at,
  c.archived,
  COUNT(cm.id)    AS enrolled_students
FROM classes c
LEFT JOIN users u  ON u.id = c.teacher_id
LEFT JOIN class_members cm ON cm.class_id = c.id
WHERE c.name IS NULL
   OR trim(c.name) = ''
GROUP BY c.id, c.class_code, c.name, u.name, u.email, c.created_at, c.archived
ORDER BY c.created_at;


-- -----------------------------------------------------------------------------
-- 1B.  Students with NO class membership at all
--      These students have progress/song records but are not enrolled in any
--      class — effectively "orphaned" from the teacher's view.
-- -----------------------------------------------------------------------------
SELECT
  u.id              AS user_id,
  u.name            AS student_name,
  u.email,
  u.created_at,
  COUNT(DISTINCT sp.id)  AS instrument_progress_records,
  COUNT(DISTINCT ss.id)  AS song_records
FROM users u
LEFT JOIN class_members cm ON cm.user_id = u.id
LEFT JOIN student_progress sp ON sp.user_id = u.id
LEFT JOIN student_songs ss    ON ss.user_id = u.id AND ss.deleted_at IS NULL
WHERE u.role = 'student'
  AND cm.class_id IS NULL
GROUP BY u.id, u.name, u.email, u.created_at
ORDER BY instrument_progress_records DESC, u.created_at;


-- -----------------------------------------------------------------------------
-- 2A.  Classes where the name is "test" (case-insensitive)
--      These are test accounts and should be removed from real data.
-- -----------------------------------------------------------------------------
SELECT
  c.id            AS class_id,
  c.name          AS class_name,
  c.class_code,
  u.name          AS teacher_name,
  u.email         AS teacher_email,
  c.created_at,
  c.archived,
  COUNT(cm.id)    AS enrolled_students
FROM classes c
LEFT JOIN users u  ON u.id = c.teacher_id
LEFT JOIN class_members cm ON cm.class_id = c.id
WHERE lower(trim(c.name)) = 'test'
GROUP BY c.id, c.name, c.class_code, u.name, u.email, c.created_at, c.archived
ORDER BY c.created_at;


-- 2A-detail.  Show exactly which students are in those test classes
SELECT
  c.name          AS class_name,
  c.class_code,
  u.name          AS student_name,
  u.email         AS student_email,
  cm.joined_at
FROM classes c
JOIN class_members cm ON cm.class_id = c.id
JOIN users u           ON u.id = cm.user_id
WHERE lower(trim(c.name)) = 'test'
ORDER BY c.name, u.name;


-- 2A-cascade.  Preview what ON DELETE CASCADE will automatically clean up
--              when you delete the test class rows.
WITH test_class_ids AS (
  SELECT id FROM classes WHERE lower(trim(name)) = 'test'
)
SELECT
  'classes'             AS affected_table,
  COUNT(*)              AS rows_affected
FROM classes
WHERE id IN (SELECT id FROM test_class_ids)

UNION ALL

SELECT
  'class_members',
  COUNT(*)
FROM class_members
WHERE class_id IN (SELECT id FROM test_class_ids)

UNION ALL

SELECT
  'pending_enrollments',
  COUNT(*)
FROM pending_enrollments
WHERE class_id IN (SELECT id FROM test_class_ids);

-- NOTE: student_progress and student_songs are user-level (not class-level) and
-- will NOT be cascade-deleted. If you want to remove progress data for students
-- who are ONLY in test classes, use the supplemental queries in PHASE 2.


-- -----------------------------------------------------------------------------
-- 3A.  Instruments with garbled / encoding-corrupted names
--      Looks for multi-byte UTF-8 sequences that survived as Latin-1 garbage,
--      e.g. "â€™", "Â", "Ã©", or any non-ASCII byte in what should be plain text.
-- -----------------------------------------------------------------------------
SELECT
  id,
  name            AS garbled_name,
  icon,
  description,
  display_order
FROM instruments
WHERE
  -- Non-ASCII characters (codepoint > 127)
  name ~ '[^\x00-\x7F]'
  -- Common double-encoding artifacts: â, Â, ã, Ã, ï, Ã©, etc.
  OR name ~* 'â|ã|Ã|Â|ï|î|ü|ö|ä|Ä|Ö|Ü|é|è|ê|ë'
ORDER BY display_order;


-- 3A-also: scan song titles and artist names for same issue
SELECT
  'songs.title'  AS source_field,
  id,
  title          AS garbled_value,
  artist
FROM songs
WHERE title ~ '[^\x00-\x7F]'
  OR title ~* 'â|ã|Ã|Â|ï|Ã©'

UNION ALL

SELECT
  'songs.artist',
  id,
  artist,
  title
FROM songs
WHERE artist ~ '[^\x00-\x7F]'
  OR artist ~* 'â|ã|Ã|Â|ï|Ã©'

ORDER BY source_field, garbled_value;


-- -----------------------------------------------------------------------------
-- 4A.  Students stuck at Level 1 — count by class
--      "Stuck" = current_level = 1 and last_updated more than 30 days ago.
--      Adjust the interval to match your academic term if needed.
-- -----------------------------------------------------------------------------
SELECT
  c.name                                       AS class_name,
  c.class_code,
  t.name                                       AS teacher_name,
  t.email                                      AS teacher_email,
  i.name                                       AS instrument,
  i.icon                                       AS instrument_icon,
  COUNT(DISTINCT sp.user_id)                   AS students_at_level_1,
  MIN(sp.last_updated)::date                   AS earliest_last_update,
  MAX(sp.last_updated)::date                   AS latest_last_update
FROM student_progress sp
JOIN instruments i     ON i.id  = sp.instrument_id
JOIN users s           ON s.id  = sp.user_id
JOIN class_members cm  ON cm.user_id = sp.user_id
JOIN classes c         ON c.id  = cm.class_id
JOIN users t           ON t.id  = c.teacher_id
WHERE sp.current_level = 1
  AND sp.last_updated < NOW() - INTERVAL '30 days'
  AND c.archived = false
GROUP BY c.id, c.name, c.class_code, t.name, t.email, i.id, i.name, i.icon
ORDER BY students_at_level_1 DESC, c.name, i.display_order;


-- 4B.  Overall Level-1 count per instrument (all students, any class age)
SELECT
  i.name                                       AS instrument,
  i.icon,
  COUNT(*)                                     AS total_students_at_level_1,
  COUNT(*) FILTER (
    WHERE sp.last_updated < NOW() - INTERVAL '30 days'
  )                                            AS stuck_30_plus_days,
  COUNT(*) FILTER (
    WHERE sp.last_updated < NOW() - INTERVAL '90 days'
  )                                            AS stuck_90_plus_days
FROM student_progress sp
JOIN instruments i ON i.id = sp.instrument_id
WHERE sp.current_level = 1
GROUP BY i.id, i.name, i.icon, i.display_order
ORDER BY i.display_order;


-- 4C.  Detailed list: students at Level 1 for 30+ days (with class context)
SELECT
  s.name                                       AS student_name,
  s.email                                      AS student_email,
  i.name                                       AS instrument,
  sp.current_level,
  sp.last_updated::date                        AS last_progress_update,
  (NOW() - sp.last_updated)::text              AS time_since_update,
  c.name                                       AS class_name,
  t.name                                       AS teacher_name
FROM student_progress sp
JOIN users s           ON s.id  = sp.user_id
JOIN instruments i     ON i.id  = sp.instrument_id
JOIN class_members cm  ON cm.user_id = sp.user_id
JOIN classes c         ON c.id  = cm.class_id
JOIN users t           ON t.id  = c.teacher_id
WHERE sp.current_level = 1
  AND sp.last_updated < NOW() - INTERVAL '30 days'
  AND c.archived = false
ORDER BY sp.last_updated ASC, c.name, s.name;


-- =============================================================================
-- PHASE 2: CLEANUP (destructive — review Phase 1 results before uncommenting)
-- =============================================================================
-- Each block is wrapped in a transaction so you can ROLLBACK if results are
-- not what you expected. Remove the ROLLBACK and replace with COMMIT when ready.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- CLEANUP 1:  Fix classes with blank names
--             (Decide on a case-by-case basis — update or delete)
-- -----------------------------------------------------------------------------
-- Option A — Rename blank-named classes so they are at least identifiable:
-- BEGIN;
-- UPDATE classes
-- SET name = 'Unnamed Class (' || class_code || ')'
-- WHERE trim(name) = '' OR name IS NULL;
-- -- Check rows affected, then either COMMIT or ROLLBACK:
-- ROLLBACK;

-- Option B — Delete blank-named classes that have zero students:
-- BEGIN;
-- DELETE FROM classes
-- WHERE (trim(name) = '' OR name IS NULL)
--   AND id NOT IN (SELECT DISTINCT class_id FROM class_members);
-- ROLLBACK;


-- -----------------------------------------------------------------------------
-- CLEANUP 2:  Remove "test" classes and their cascade-linked records
-- -----------------------------------------------------------------------------
-- Step 1: Review 2A and 2A-detail above. Then uncomment:
-- BEGIN;
-- DELETE FROM classes
-- WHERE lower(trim(name)) = 'test';
-- -- ON DELETE CASCADE will automatically remove class_members and
-- -- pending_enrollments rows for these classes.
-- ROLLBACK;

-- Step 2 (optional): Remove progress + song data for students who were ONLY
-- in test classes and have no other class membership.
-- Only run this if you confirmed those students have no real data.
-- BEGIN;
-- WITH test_only_students AS (
--   -- Students who are no longer in any class after the test class deletion
--   SELECT u.id
--   FROM users u
--   WHERE u.role = 'student'
--     AND NOT EXISTS (
--       SELECT 1 FROM class_members cm WHERE cm.user_id = u.id
--     )
-- )
-- SELECT u.id, u.name, u.email  -- Preview first
-- FROM users u
-- WHERE u.id IN (SELECT id FROM test_only_students);
-- -- Replace SELECT with DELETE FROM users WHERE id IN (...) when ready.
-- ROLLBACK;


-- -----------------------------------------------------------------------------
-- CLEANUP 3:  Fix garbled instrument names
--             Identify correct names from the results of 3A, then update.
-- -----------------------------------------------------------------------------
-- Example: if 3A shows name = 'Ã©lectric Guitar', the real value is 'Electric Guitar'
-- Adjust the WHERE clause and SET value to match each garbled row you found.

-- BEGIN;
-- UPDATE instruments
-- SET name = 'Correct Name Here'   -- replace with the actual intended name
-- WHERE name = 'Garbled Name Here'; -- replace with the exact garbled value from 3A
-- ROLLBACK;

-- If the name is truly unrecoverable and the instrument has no linked data, delete:
-- BEGIN;
-- DELETE FROM instruments
-- WHERE name ~ '[^\x00-\x7F]'
--   AND id NOT IN (SELECT DISTINCT instrument_id FROM student_progress)
--   AND id NOT IN (SELECT DISTINCT instrument_id FROM student_songs)
--   AND id NOT IN (SELECT DISTINCT instrument_id FROM song_ratings);
-- ROLLBACK;


-- =============================================================================
-- PHASE 3: POST-CLEANUP SUMMARY
-- Run this after Phase 2 to confirm row counts
-- =============================================================================
SELECT
  (SELECT COUNT(*) FROM classes WHERE trim(name) = '' OR name IS NULL)
    AS blank_class_names_remaining,

  (SELECT COUNT(*) FROM classes WHERE lower(trim(name)) = 'test')
    AS test_classes_remaining,

  (SELECT COUNT(*) FROM instruments WHERE name ~ '[^\x00-\x7F]')
    AS garbled_instruments_remaining,

  (SELECT COUNT(*) FROM student_progress WHERE current_level = 1)
    AS total_students_at_level_1,

  (SELECT COUNT(*) FROM student_progress
   WHERE current_level = 1 AND last_updated < NOW() - INTERVAL '30 days')
    AS students_stuck_level_1_30d,

  (SELECT COUNT(*) FROM users u
   WHERE u.role = 'student'
     AND NOT EXISTS (SELECT 1 FROM class_members cm WHERE cm.user_id = u.id))
    AS students_with_no_class;
