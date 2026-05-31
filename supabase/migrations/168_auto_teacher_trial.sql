-- ============================================================
-- MIGRATION 168: Auto 90-day trial for new teachers
-- ============================================================
-- Creates a trialing individual subscription for any teacher
-- who has no existing subscription row. Idempotent — safe to
-- call on every login; only fires once per account.

CREATE OR REPLACE FUNCTION create_teacher_auto_trial()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  UUID;
  v_role TEXT;
BEGIN
  v_uid := auth.uid();

  SELECT role INTO v_role FROM users WHERE id = v_uid;

  IF v_role IS DISTINCT FROM 'teacher' THEN
    RETURN json_build_object('success', false, 'reason', 'not_teacher');
  END IF;

  IF EXISTS (SELECT 1 FROM subscriptions WHERE teacher_id = v_uid) THEN
    RETURN json_build_object('success', false, 'reason', 'already_has_subscription');
  END IF;

  INSERT INTO subscriptions (teacher_id, plan_type, status, current_period_start, current_period_end)
  VALUES (v_uid, 'individual', 'trialing', NOW(), NOW() + INTERVAL '90 days');

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION create_teacher_auto_trial() TO authenticated;
