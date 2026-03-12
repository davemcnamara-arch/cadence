-- ============================================================
-- MIGRATION 099: Add subscriptions table
--
-- Tracks subscription state for individual teachers and schools.
--   - school_id NULL  → individual teacher subscription
--   - teacher_id NULL → school-level license (all teachers in school)
--
-- Access is handled entirely via SECURITY DEFINER RPCs; RLS is
-- enabled with no policies so direct table access is denied.
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

-- Lock the table down; all access goes through RPCs below
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RPC: get_my_subscription()
-- Returns the caller's active subscription — either their own
-- individual row or a school-level row for a school they belong to.
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_subscription()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_uid  UUID;
  v_row  subscriptions%ROWTYPE;
BEGIN
  v_uid := auth.uid();

  -- Individual subscription for this teacher
  SELECT * INTO v_row
  FROM subscriptions
  WHERE teacher_id = v_uid
  LIMIT 1;

  IF FOUND THEN
    RETURN row_to_json(v_row);
  END IF;

  -- School-level subscription for any school the caller belongs to
  SELECT s.* INTO v_row
  FROM subscriptions s
  JOIN school_members sm ON sm.school_id = s.school_id
  WHERE sm.user_id = v_uid
    AND s.teacher_id IS NULL
  LIMIT 1;

  IF FOUND THEN
    RETURN row_to_json(v_row);
  END IF;

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_subscription() TO authenticated;

-- ============================================================
-- RPC: admin_get_subscriptions()
-- Returns all subscription rows. Admin only.
-- ============================================================
CREATE OR REPLACE FUNCTION admin_get_subscriptions()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
  END IF;

  RETURN (
    SELECT COALESCE(json_agg(s ORDER BY s.created_at DESC), '[]'::JSON)
    FROM subscriptions s
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_subscriptions() TO authenticated;

-- ============================================================
-- RPC: admin_upsert_subscription(...)
-- Insert or update a subscription row. Admin only.
-- Pass p_id => NULL to insert, or an existing UUID to update.
-- ============================================================
CREATE OR REPLACE FUNCTION admin_upsert_subscription(
  p_id                     UUID,
  p_school_id              UUID,
  p_teacher_id             UUID,
  p_plan_type              TEXT,
  p_status                 TEXT,
  p_stripe_subscription_id TEXT,
  p_stripe_customer_id     TEXT,
  p_current_period_start   TIMESTAMPTZ,
  p_current_period_end     TIMESTAMPTZ
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
  END IF;

  IF p_id IS NULL THEN
    -- Insert
    INSERT INTO subscriptions (
      school_id, teacher_id, plan_type, status,
      stripe_subscription_id, stripe_customer_id,
      current_period_start, current_period_end
    ) VALUES (
      p_school_id, p_teacher_id, p_plan_type, p_status,
      p_stripe_subscription_id, p_stripe_customer_id,
      p_current_period_start, p_current_period_end
    )
    RETURNING id INTO v_id;
  ELSE
    -- Update
    UPDATE subscriptions SET
      school_id              = p_school_id,
      teacher_id             = p_teacher_id,
      plan_type              = p_plan_type,
      status                 = p_status,
      stripe_subscription_id = p_stripe_subscription_id,
      stripe_customer_id     = p_stripe_customer_id,
      current_period_start   = p_current_period_start,
      current_period_end     = p_current_period_end
    WHERE id = p_id
    RETURNING id INTO v_id;

    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'message', 'Subscription not found');
    END IF;
  END IF;

  RETURN json_build_object('success', true, 'id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_upsert_subscription(UUID, UUID, UUID, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated;

-- ============================================================
-- RPC: admin_delete_subscription(p_id)
-- Delete a subscription row. Admin only.
-- ============================================================
CREATE OR REPLACE FUNCTION admin_delete_subscription(p_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
  END IF;

  DELETE FROM subscriptions WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'Subscription not found');
  END IF;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_delete_subscription(UUID) TO authenticated;
