-- ============================================================
-- MIGRATION 171: switch_trial_to_individual()
-- ============================================================
-- Allows a teacher on an auto-created school plan trial to
-- downgrade to an individual plan trial. Only permitted when
-- the subscription is a trial with no Stripe subscription ID
-- (i.e. the auto-trial, not a paid subscription).

CREATE OR REPLACE FUNCTION switch_trial_to_individual()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID;
BEGIN
  v_uid := auth.uid();

  UPDATE subscriptions
     SET plan_type = 'individual'
   WHERE teacher_id          = v_uid
     AND plan_type           = 'school'
     AND status              = 'trialing'
     AND stripe_subscription_id IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No eligible school trial found to downgrade';
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION switch_trial_to_individual() TO authenticated;
