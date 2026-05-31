-- ============================================================
-- MIGRATION 158: Add soft-launch school promo code
--
-- New school-plan code for teachers signing up via the local
-- music teachers network soft launch. Same 90-day trial as
-- BIGGIG10SCHOOL but a distinct code for source tracking.
-- ============================================================

INSERT INTO promo_codes (code, plan_type, uses_remaining, expires_at)
VALUES ('MUSICNETWORK25', 'school', 50, NOW() + INTERVAL '180 days');
