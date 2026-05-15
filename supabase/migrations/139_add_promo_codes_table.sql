-- ============================================================
-- MIGRATION 139: Add promo_codes table
--
-- Stores redeemable promo codes for 30-day trials.
-- Access is handled via the redeem_promo_code() RPC (migration 140).
-- ============================================================

CREATE TABLE promo_codes (
  code            TEXT PRIMARY KEY,
  uses_remaining  INTEGER NOT NULL,
  expires_at      TIMESTAMPTZ NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Lock the table down; all access goes through RPCs
ALTER TABLE promo_codes ENABLE ROW LEVEL SECURITY;

-- Seed the launch promo code
INSERT INTO promo_codes (code, uses_remaining, expires_at)
VALUES ('BIGGIG10', 100, NOW() + INTERVAL '60 days');
