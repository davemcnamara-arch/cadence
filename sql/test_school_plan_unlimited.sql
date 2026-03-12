-- ============================================================
-- TEST HELPER: School plan — unlimited students/teachers
--
-- Verifies that a teacher on a School subscription:
--   • Can enroll more than 15 students without hitting a limit
--   • Sees "School plan · unlimited teachers and students" in the
--     plan banner
--   • Can see the School/Teachers nav tab (hidden on Individual)
--
-- Usage:
--   STEP 1 — Replace YOUR_TEACHER_ID_HERE, then run SECTION A
--            to switch the teacher to a School subscription.
--   STEP 2 — Sign the teacher out and back in (or hard-refresh).
--   STEP 3 — In the UI:
--              a. Confirm plan banner shows
--                 "School plan · unlimited teachers and students"
--              b. Confirm the School/Teachers nav tab is visible
--   STEP 4 — Run SECTION B to seed 16+ students into the class
--            and confirm no rejection.
--   STEP 5 — Run SECTION C to restore the original subscription
--            when done.
-- ============================================================

-- ============================================================
-- SECTION A — Upgrade the teacher's subscription to School plan
-- ============================================================
DO $$
DECLARE
  v_teacher_id  UUID := 'YOUR_TEACHER_ID_HERE';
  v_sub_id      UUID;
  v_old_plan    TEXT;
BEGIN
  IF v_teacher_id::TEXT = 'YOUR_TEACHER_ID_HERE' THEN
    RAISE EXCEPTION 'Replace YOUR_TEACHER_ID_HERE with the teacher''s auth UUID. '
                    'Find it with: SELECT id, email FROM auth.users WHERE email = ''teacher@example.com'';';
  END IF;

  -- Read current plan so we can restore it in Section C
  SELECT id, plan_type
  INTO   v_sub_id, v_old_plan
  FROM   subscriptions
  WHERE  teacher_id = v_teacher_id
  ORDER BY
    CASE status WHEN 'active' THEN 1 WHEN 'trialing' THEN 2 ELSE 3 END,
    current_period_end DESC
  LIMIT 1;

  IF v_sub_id IS NULL THEN
    RAISE EXCEPTION 'No subscription row found for teacher %. '
                    'Insert one first (status = ''active'', plan_type = ''individual'').', v_teacher_id;
  END IF;

  RAISE NOTICE 'Current plan for teacher %: % (id = %)', v_teacher_id, v_old_plan, v_sub_id;

  -- Upgrade to school plan
  UPDATE subscriptions
  SET    plan_type  = 'school',
         school_id  = NULL,       -- individual school-plan row (teacher_id is set)
         updated_at = NOW()
  WHERE  id = v_sub_id;

  RAISE NOTICE 'SUCCESS — subscription % set to plan_type = ''school''.', v_sub_id;
  RAISE NOTICE 'Sign out and back in, then verify the UI.';
  RAISE NOTICE 'To restore, run SECTION C with sub_id = ''%'' and old plan = ''%''.', v_sub_id, v_old_plan;
END $$;


-- ============================================================
-- SECTION B — Attempt to enroll 16 students (over the 15-cap)
--
-- This runs server-side using check_can_add_student(), which
-- should return TRUE for school plans and allow all inserts.
-- ============================================================
DO $$
DECLARE
  v_teacher_id  UUID := 'YOUR_TEACHER_ID_HERE';
  v_class_id    UUID := 'YOUR_CLASS_ID_HERE';
  v_can_add     BOOLEAN;
  v_count       INT;
BEGIN
  IF v_class_id::TEXT = 'YOUR_CLASS_ID_HERE' THEN
    RAISE EXCEPTION 'Replace YOUR_CLASS_ID_HERE with the class UUID. '
                    'Find it with: SELECT id, name FROM classes WHERE teacher_id = ''<teacher_id>'' AND archived = false;';
  END IF;

  -- check_can_add_student should always return TRUE for school plans
  SELECT check_can_add_student(v_teacher_id) INTO v_can_add;

  IF v_can_add THEN
    RAISE NOTICE 'PASS — check_can_add_student() returned TRUE for School plan.';
  ELSE
    RAISE NOTICE 'FAIL — check_can_add_student() returned FALSE. School plan is not properly detected.';
  END IF;

  -- Count currently enrolled students
  SELECT COUNT(DISTINCT user_id)
  INTO   v_count
  FROM   class_members
  WHERE  class_id = v_class_id;

  RAISE NOTICE 'Class currently has % enrolled students.', v_count;
  RAISE NOTICE 'To test enrolling a 16th+ student: use the class code in the UI, or run '
               'sql/seed_test_students.sql with v_count set to 16.';
END $$;


-- ============================================================
-- SECTION C — Restore original subscription plan
-- ============================================================
-- UPDATE subscriptions
-- SET plan_type = 'individual'   -- or whatever the original plan was
-- WHERE id = 'YOUR_SUB_ID_HERE';
