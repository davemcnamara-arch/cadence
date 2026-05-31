-- ============================================================
-- MIGRATION 158: Add soft-launch promo codes
--
-- School and individual codes for the local music teachers
-- network soft launch. Same 90-day trial as existing codes
-- but distinct for source tracking.
-- ============================================================

INSERT INTO promo_codes (code, plan_type, uses_remaining, expires_at)
VALUES
  ('CADENCESCHOOLTRIAL26',      'school',      50, NOW() + INTERVAL '180 days'),
  ('CADENCEINDIVIDUALTRIAL26',  'individual',  50, NOW() + INTERVAL '180 days');
