-- ============================================================
-- MIGRATION 169: Allow school promo code to upgrade an individual auto-trial
-- ============================================================
-- Before auto-trial (migration 168), every teacher started with no
-- subscription row, so the re-redemption guard in redeem_promo_code()
-- ("block if ANY subscription exists") was safe.
--
-- Now that all new teachers get an auto individual trial, school plan
-- promo codes would be incorrectly blocked. This migration rewrites the
-- guard to allow a school plan promo code to upgrade an individual trial
-- (one that was never paid, i.e. stripe_subscription_id IS NULL).
-- All other blocking rules remain in place.

CREATE OR REPLACE FUNCTION redeem_promo_code(promo_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       UUID;
  v_code      TEXT;
  v_uses      INTEGER;
  v_exp       TIMESTAMPTZ;
  v_plan_type TEXT;
BEGIN
  v_uid  := auth.uid();
  v_code := upper(trim(promo_code));

  SELECT uses_remaining, expires_at, COALESCE(plan_type, 'individual')
    INTO v_uses, v_exp, v_plan_type
    FROM promo_codes
   WHERE code = v_code;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid code';
  END IF;

  IF v_uses <= 0 THEN
    RAISE EXCEPTION 'No uses remaining';
  END IF;

  IF v_exp <= NOW() THEN
    RAISE EXCEPTION 'Code has expired';
  END IF;

  -- Re-redemption guard
  IF EXISTS (SELECT 1 FROM subscriptions WHERE teacher_id = v_uid) THEN
    -- Special case: allow a school plan code to upgrade an unpaid individual trial.
    -- This covers teachers who received an auto-trial (migration 168) and then
    -- receive a school promo code from an admin or partner.
    IF v_plan_type = 'school'
      AND EXISTS (
        SELECT 1 FROM subscriptions
         WHERE teacher_id = v_uid
           AND plan_type = 'individual'
           AND stripe_subscription_id IS NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM subscriptions
         WHERE teacher_id = v_uid
           AND (plan_type = 'school' OR stripe_subscription_id IS NOT NULL)
      )
    THEN
      -- Consume one use
      UPDATE promo_codes SET uses_remaining = uses_remaining - 1 WHERE code = v_code;

      -- Upgrade the existing individual trial to a school trial in-place
      UPDATE subscriptions
         SET plan_type             = 'school',
             status                = 'trialing',
             current_period_start  = NOW(),
             current_period_end    = NOW() + INTERVAL '90 days'
       WHERE teacher_id = v_uid
         AND plan_type = 'individual'
         AND stripe_subscription_id IS NULL;

      RETURN json_build_object('success', true);
    END IF;

    RAISE EXCEPTION 'Promo codes can only be used once per account';
  END IF;

  -- Consume one use
  UPDATE promo_codes SET uses_remaining = uses_remaining - 1 WHERE code = v_code;

  INSERT INTO subscriptions (teacher_id, plan_type, status, current_period_start, current_period_end)
  VALUES (v_uid, v_plan_type, 'trialing', NOW(), NOW() + INTERVAL '90 days');

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_promo_code(TEXT) TO authenticated;
