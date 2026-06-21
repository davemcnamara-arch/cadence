-- ============================================================
-- MIGRATION 177: Atomic student-to-teacher role switch with trial
-- ============================================================
-- When an existing student signs in as a teacher, auth.js calls
-- patchDirect() to update the role, then onUserSignedIn() calls
-- create_teacher_auto_trial(). If the REST PATCH failed silently
-- (RLS edge case, stale token, network blip), create_teacher_auto_trial
-- sees role='student' in the DB and skips trial creation, causing a
-- redirect to subscribe.html.
--
-- This function does both in one atomic SECURITY DEFINER call:
-- 1. Updates the calling user's role to 'teacher'
-- 2. Creates a 90-day school trial if no subscription exists
-- ============================================================

CREATE OR REPLACE FUNCTION switch_student_to_teacher_with_trial()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid          UUID;
  v_current_role TEXT;
BEGIN
  v_uid := auth.uid();

  SELECT role INTO v_current_role FROM users WHERE id = v_uid;

  IF v_current_role IS NULL THEN
    RETURN json_build_object('success', false, 'reason', 'user_not_found');
  END IF;

  IF v_current_role <> 'student' THEN
    RETURN json_build_object('success', false, 'reason', 'not_student');
  END IF;

  UPDATE users SET role = 'teacher', updated_at = NOW() WHERE id = v_uid;

  IF NOT EXISTS (SELECT 1 FROM subscriptions WHERE teacher_id = v_uid) THEN
    INSERT INTO subscriptions (teacher_id, plan_type, status, current_period_start, current_period_end)
    VALUES (v_uid, 'school', 'trialing', NOW(), NOW() + INTERVAL '90 days');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION switch_student_to_teacher_with_trial() TO authenticated;
