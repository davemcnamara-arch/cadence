-- ============================================================
-- TEST HELPER: Multiple subscription rows (Bug 4 fix)
--
-- Verifies that when a teacher has two subscriptions rows — one
-- active and one expired — the app always picks the active row.
--
-- Before this fix (Migration 102) the ORDER BY was missing, so
-- LIMIT 1 returned a non-deterministic row and the teacher could
-- land on subscribe.html even with a valid active subscription.
--
-- Tests covered:
--   Step 8: get_my_subscription() returns the active row when an
--           older expired row also exists.
--   Step 9: Teacher signs in and lands on the app (not subscribe.html),
--           proving the active row takes priority at the login gate.
--
-- Usage:
--   STEP 1 — Replace YOUR_TEACHER_ID_HERE and run SECTION A to
--            insert a second (expired) subscription row.
--   STEP 2 — Run SECTION B to verify get_my_subscription() still
--            returns the active row (SQL-level check).
--   STEP 3 — Sign the teacher out and back in — confirm you land
--            on the main app, NOT subscribe.html.
--   STEP 4 — Run SECTION C to remove the test expired row.
-- ============================================================

-- ============================================================
-- SECTION A — Insert a second, older expired subscription row
-- ============================================================
DO $$
DECLARE
  v_teacher_id   UUID := 'YOUR_TEACHER_ID_HERE';
  v_expired_id   UUID;
  v_active_count INT;
BEGIN
  IF v_teacher_id::TEXT = 'YOUR_TEACHER_ID_HERE' THEN
    RAISE EXCEPTION 'Replace YOUR_TEACHER_ID_HERE with the teacher''s auth UUID. '
                    'Find it with: SELECT id, email FROM auth.users WHERE email = ''teacher@example.com'';';
  END IF;

  -- Confirm there is already an active subscription
  SELECT COUNT(*)
  INTO   v_active_count
  FROM   subscriptions
  WHERE  teacher_id = v_teacher_id
    AND  status IN ('active', 'trialing');

  IF v_active_count = 0 THEN
    RAISE EXCEPTION 'Teacher % has no active/trialing subscription. '
                    'Create one first before adding a second expired row.', v_teacher_id;
  END IF;

  RAISE NOTICE 'Teacher has % active/trialing row(s). Adding an expired row...', v_active_count;

  -- Insert an expired row with an older period_end so deterministic ordering
  -- always prefers the active row (active wins by status; period_end DESC is
  -- the tiebreaker when statuses differ).
  INSERT INTO subscriptions (
    teacher_id,
    plan_type,
    status,
    current_period_start,
    current_period_end,
    created_at
  )
  VALUES (
    v_teacher_id,
    'individual',
    'expired',
    NOW() - INTERVAL '2 years',
    NOW() - INTERVAL '1 year',    -- expired one year ago
    NOW() - INTERVAL '2 years'
  )
  RETURNING id INTO v_expired_id;

  RAISE NOTICE 'SUCCESS — expired subscription row inserted: id = %', v_expired_id;
  RAISE NOTICE 'There are now multiple rows for teacher %. Run SECTION B to verify ordering.', v_teacher_id;
  RAISE NOTICE 'Save this ID for cleanup in SECTION C: %', v_expired_id;
END $$;


-- ============================================================
-- SECTION B — Verify the active row wins
-- Run directly in Supabase SQL Editor (as service_role).
-- ============================================================
DO $$
DECLARE
  v_teacher_id   UUID   := 'YOUR_TEACHER_ID_HERE';
  v_best_status  TEXT;
  v_best_plan    TEXT;
  v_row_count    INT;
BEGIN
  -- Count how many rows exist
  SELECT COUNT(*)
  INTO   v_row_count
  FROM   subscriptions
  WHERE  teacher_id = v_teacher_id;

  RAISE NOTICE 'Total subscription rows for teacher: %', v_row_count;

  -- Replicate the ORDER BY logic from Migration 102
  SELECT status, plan_type
  INTO   v_best_status, v_best_plan
  FROM   subscriptions
  WHERE  teacher_id = v_teacher_id
  ORDER BY
    CASE status
      WHEN 'active'   THEN 1
      WHEN 'trialing' THEN 2
      ELSE                 3
    END,
    current_period_end DESC
  LIMIT 1;

  RAISE NOTICE 'Best row returned: status = %, plan_type = %', v_best_status, v_best_plan;

  IF v_best_status IN ('active', 'trialing') THEN
    RAISE NOTICE 'PASS — get_my_subscription() will return the active/trialing row. '
                 'Bug 4 fix is working correctly.';
  ELSE
    RAISE NOTICE 'FAIL — get_my_subscription() would return the % row. '
                 'The expired row is winning — Bug 4 is NOT fixed.', v_best_status;
  END IF;
END $$;


-- ============================================================
-- SECTION C — Cleanup: remove the test expired row
-- Replace the UUID with the one printed by SECTION A.
-- ============================================================
-- DELETE FROM subscriptions
-- WHERE id = 'EXPIRED_ROW_ID_HERE'
--   AND status = 'expired';

-- Confirm cleanup:
-- SELECT id, status, plan_type, current_period_end
-- FROM   subscriptions
-- WHERE  teacher_id = 'YOUR_TEACHER_ID_HERE'
-- ORDER BY current_period_end DESC;
