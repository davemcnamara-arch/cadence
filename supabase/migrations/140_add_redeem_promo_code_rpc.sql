-- ============================================================
-- MIGRATION 140: Add redeem_promo_code RPC
--
-- Validates a promo code and upserts a 30-day trialing subscription
-- for the calling authenticated user. Raises an exception on failure
-- so the JS client receives a clear error message.
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

  -- Consume one use
  UPDATE promo_codes
     SET uses_remaining = uses_remaining - 1
   WHERE code = v_code;

  -- Upsert a trialing subscription for the calling teacher.
  -- Try update first; insert only if no existing row.
  UPDATE subscriptions
     SET status               = 'trialing',
         current_period_start = NOW(),
         current_period_end   = NOW() + INTERVAL '30 days'
   WHERE teacher_id = v_uid;

  IF NOT FOUND THEN
    INSERT INTO subscriptions (teacher_id, plan_type, status, current_period_start, current_period_end)
    VALUES (v_uid, 'individual', 'trialing', NOW(), NOW() + INTERVAL '30 days');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION redeem_promo_code(TEXT) TO authenticated;
