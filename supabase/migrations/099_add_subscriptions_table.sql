-- ============================================================
-- MIGRATION 099: Add subscriptions table
--
-- Tracks subscription state for individual teachers and schools.
--   - school_id NULL  → individual teacher subscription
--   - teacher_id NULL → school-level license (all teachers in school)
-- ============================================================

CREATE TABLE subscriptions (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  school_id               UUID REFERENCES schools(id) ON DELETE CASCADE,
  teacher_id              UUID REFERENCES users(id) ON DELETE CASCADE,
  plan_type               TEXT NOT NULL CHECK (plan_type IN ('individual', 'school')),
  status                  TEXT NOT NULL CHECK (status IN ('active', 'trialing', 'expired', 'cancelled')),
  stripe_subscription_id  TEXT,
  stripe_customer_id      TEXT,
  current_period_start    TIMESTAMP WITH TIME ZONE NOT NULL,
  current_period_end      TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at              TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for common lookups
CREATE INDEX idx_subscriptions_teacher_id ON subscriptions(teacher_id);
CREATE INDEX idx_subscriptions_school_id  ON subscriptions(school_id);

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Admins: full read/write access
CREATE POLICY "Admins can read all subscriptions"
  ON subscriptions FOR SELECT
  USING (is_admin());

CREATE POLICY "Admins can insert subscriptions"
  ON subscriptions FOR INSERT
  WITH CHECK (is_admin());

CREATE POLICY "Admins can update subscriptions"
  ON subscriptions FOR UPDATE
  USING (is_admin());

CREATE POLICY "Admins can delete subscriptions"
  ON subscriptions FOR DELETE
  USING (is_admin());

-- Teachers: read their own individual subscription row
CREATE POLICY "Teachers can read their own subscription"
  ON subscriptions FOR SELECT
  USING (teacher_id = auth.uid());

-- Teachers: read a school-level subscription for their school
CREATE POLICY "Teachers can read their school subscription"
  ON subscriptions FOR SELECT
  USING (
    school_id IS NOT NULL
    AND teacher_id IS NULL
    AND EXISTS (
      SELECT 1
      FROM school_members sm
      WHERE sm.school_id = subscriptions.school_id
        AND sm.user_id = auth.uid()
    )
  );
