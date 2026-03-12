-- Seed active school-level subscriptions for Mount Carmel College and Test School.
-- Run in the Supabase SQL editor (postgres role bypasses RLS).
--
-- Uses INSERT ... ON CONFLICT DO UPDATE so it is safe to re-run:
-- if a subscription row already exists for the school it is refreshed
-- to active status with a new 1-year period.

-- Ensure the unique index exists so ON CONFLICT works.
-- (Skip if already present.)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE tablename = 'subscriptions'
      AND indexname  = 'idx_subscriptions_school_id_unique'
  ) THEN
    CREATE UNIQUE INDEX idx_subscriptions_school_id_unique
      ON subscriptions (school_id)
      WHERE teacher_id IS NULL;
  END IF;
END $$;

INSERT INTO subscriptions (
  school_id,
  teacher_id,
  plan_type,
  status,
  stripe_subscription_id,
  stripe_customer_id,
  current_period_start,
  current_period_end
)
SELECT
  s.id          AS school_id,
  NULL          AS teacher_id,
  'school'      AS plan_type,
  'active'      AS status,
  NULL          AS stripe_subscription_id,
  NULL          AS stripe_customer_id,
  NOW()         AS current_period_start,
  NOW() + INTERVAL '1 year' AS current_period_end
FROM schools s
WHERE lower(s.name) IN (
  lower('Mount Carmel College'),
  lower('test school')
)
ON CONFLICT (school_id) WHERE teacher_id IS NULL
DO UPDATE SET
  status               = 'active',
  current_period_start = NOW(),
  current_period_end   = NOW() + INTERVAL '1 year';
