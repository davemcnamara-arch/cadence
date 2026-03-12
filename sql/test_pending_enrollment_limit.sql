-- ============================================================
-- TEST HELPER: Pending enrollments + limit enforcement (Bug 3)
--
-- Verifies that when a teacher pre-adds an email address while
-- their class is already at the 15-student cap, the pending row
-- is NOT discarded when that student logs in for the first time —
-- it stays in pending_enrollments so it can be processed later.
--
-- Prerequisites:
--   • You have a teacher user with an active Individual subscription
--   • That teacher has a class that is already at 15 enrolled students
--     (use sql/seed_test_students.sql to fill it first if needed)
--   • You have a student who has NOT signed up yet
--
-- Usage:
--   STEP 1 — Replace the three placeholder values below, then run
--            SECTION A to insert the pending_enrollment row.
--   STEP 2 — Have the new student sign in for the first time
--            (Google OAuth or email/password).  The app will call
--            process_pending_enrollments() automatically.
--   STEP 3 — Run SECTION B to verify the row is still there.
--   STEP 4 — Run SECTION C to clean up when done.
-- ============================================================

-- ============================================================
-- CONFIGURATION — replace all three values before running
-- ============================================================
DO $$
BEGIN
  -- Validate placeholders
  IF 'YOUR_CLASS_ID_HERE'   = 'YOUR_CLASS_ID_HERE'   THEN RAISE EXCEPTION 'Set v_class_id to the UUID of the at-capacity class'; END IF;
  IF 'YOUR_TEACHER_ID_HERE' = 'YOUR_TEACHER_ID_HERE' THEN RAISE EXCEPTION 'Set v_teacher_id to the teacher''s auth UUID'; END IF;
  IF 'STUDENT_EMAIL_HERE'   = 'STUDENT_EMAIL_HERE'   THEN RAISE EXCEPTION 'Set v_student_email to the new student''s email address'; END IF;
END $$;

-- ============================================================
-- SECTION A — Set up the pending enrollment
-- Run this BEFORE the student signs in.
-- ============================================================
DO $$
DECLARE
  v_class_id      UUID   := 'YOUR_CLASS_ID_HERE';
  v_teacher_id    UUID   := 'YOUR_TEACHER_ID_HERE';
  v_student_email TEXT   := 'STUDENT_EMAIL_HERE';
  v_enrolled      INT;
  v_pending_id    UUID;
BEGIN
  -- Safety check: confirm the class really is at the 15-student cap
  SELECT COUNT(DISTINCT cm.user_id)
  INTO   v_enrolled
  FROM   class_members cm
  JOIN   classes c ON c.id = cm.class_id
  WHERE  c.teacher_id = v_teacher_id
    AND  c.archived   = false;

  IF v_enrolled < 15 THEN
    RAISE NOTICE 'WARNING: teacher currently has % students (< 15). '
                 'Fill the class to 15 first with sql/seed_test_students.sql '
                 'then re-run this section.', v_enrolled;
  ELSE
    RAISE NOTICE 'OK — teacher is at % students (cap is 15).', v_enrolled;
  END IF;

  -- Insert the pending enrollment (idempotent)
  INSERT INTO pending_enrollments (class_id, email, added_by)
  VALUES (v_class_id, LOWER(v_student_email), v_teacher_id)
  ON CONFLICT (class_id, email) DO NOTHING
  RETURNING id INTO v_pending_id;

  IF v_pending_id IS NOT NULL THEN
    RAISE NOTICE 'SUCCESS — pending_enrollments row inserted: id = %', v_pending_id;
  ELSE
    RAISE NOTICE 'Row already existed — no duplicate inserted.';
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE 'Next step: have the student (%) sign in for the first time.', v_student_email;
  RAISE NOTICE 'Then run SECTION B to verify the row was NOT consumed.';
END $$;


-- ============================================================
-- SECTION B — Verify the pending row survived login
-- Run this AFTER the student has signed in.
-- ============================================================
DO $$
DECLARE
  v_class_id      UUID := 'YOUR_CLASS_ID_HERE';
  v_student_email TEXT := 'STUDENT_EMAIL_HERE';
  v_pending_count INT;
  v_member_count  INT;
BEGIN
  -- 1. Row should still be in pending_enrollments
  SELECT COUNT(*)
  INTO   v_pending_count
  FROM   pending_enrollments
  WHERE  class_id = v_class_id
    AND  LOWER(email) = LOWER(v_student_email);

  -- 2. Student should NOT have been enrolled in class_members
  SELECT COUNT(*)
  INTO   v_member_count
  FROM   class_members cm
  JOIN   auth.users    u  ON u.id = cm.user_id
  WHERE  cm.class_id  = v_class_id
    AND  LOWER(u.email) = LOWER(v_student_email);

  IF v_pending_count = 1 AND v_member_count = 0 THEN
    RAISE NOTICE 'PASS — pending row is still present and student is NOT enrolled. '
                 'Bug 3 fix is working correctly.';
  ELSIF v_pending_count = 0 AND v_member_count = 0 THEN
    RAISE NOTICE 'FAIL — pending row was deleted but student is NOT enrolled. '
                 'The row was discarded without enrolling the student — Bug 3 is NOT fixed.';
  ELSIF v_member_count > 0 THEN
    RAISE NOTICE 'FAIL — student WAS enrolled despite the class being at 15 students. '
                 'The tier limit is not being enforced during pending enrollment processing.';
  ELSE
    RAISE NOTICE 'UNEXPECTED STATE — pending_count=%, member_count=%',
                 v_pending_count, v_member_count;
  END IF;
END $$;


-- ============================================================
-- SECTION C — Cleanup (run separately after testing)
-- ============================================================
-- DELETE FROM pending_enrollments
-- WHERE class_id = 'YOUR_CLASS_ID_HERE'
--   AND LOWER(email) = 'STUDENT_EMAIL_HERE';
