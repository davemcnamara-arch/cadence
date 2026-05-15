-- ============================================================
-- MIGRATION 141: Block promo code re-redemption
--
-- Adds an existing-subscription guard to redeem_promo_code() so
-- a teacher who already used a promo trial (even if now expired)
-- cannot redeem again to refresh their 30-day window.
-- ============================================================

CREATE OR REPLACE FUNCTION redeem_promo_code(promo_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  UUID;
  v_code TEXT;
  v_uses INTEGER;
  v_exp  TIMESTAMPTZ;
BEGIN
  v_uid  := auth.uid();
  v_code := upper(trim(promo_code));

  SELECT uses_remaining, expires_at
    INTO v_uses, v_exp
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

  -- Block re-redemption: each account gets one promo trial
  IF EXISTS (SELECT 1 FROM subscriptions WHERE teacher_id = v_uid) THEN
    RAISE EXCEPTION 'Promo codes can only be used once per account';
  END IF;

  -- Consume one use
  UPDATE promo_codes
     SET uses_remaining = uses_remaining - 1
   WHERE code = v_code;

  -- Insert a new trialing subscription for the calling teacher
  INSERT INTO subscriptions (teacher_id, plan_type, status, current_period_start, current_period_end)
  VALUES (v_uid, 'individual', 'trialing', NOW(), NOW() + INTERVAL '30 days');

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_promo_code(TEXT) TO authenticated;
