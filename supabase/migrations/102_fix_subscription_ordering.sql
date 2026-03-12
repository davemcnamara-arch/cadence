-- ============================================================
-- MIGRATION 102: Add deterministic ORDER BY to subscription lookups
--
-- get_my_subscription(), get_subscription_with_count(), and
-- check_can_add_student() all used LIMIT 1 without ORDER BY.
-- If a teacher had more than one subscription row (e.g., an old
-- expired record alongside a new active one) the query returned
-- a random row.
--
-- Fix: order by status preference (active → trialing → others)
-- then by current_period_end DESC so the most-recently-valid
-- subscription wins.
-- ============================================================

-- ============================================================
-- get_my_subscription()
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_subscription()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_uid UUID;
  v_row subscriptions%ROWTYPE;
BEGIN
  v_uid := auth.uid();

  -- Individual subscription — prefer active, then trialing, then newest
  SELECT * INTO v_row
  FROM subscriptions
  WHERE teacher_id = v_uid
  ORDER BY
    CASE status
      WHEN 'active'   THEN 1
      WHEN 'trialing' THEN 2
      ELSE                 3
    END,
    current_period_end DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN row_to_json(v_row);
  END IF;

  -- School-level subscription for any school the caller belongs to
  SELECT s.* INTO v_row
  FROM subscriptions s
  JOIN school_members sm ON sm.school_id = s.school_id
  WHERE sm.user_id    = v_uid
    AND s.teacher_id IS NULL
  ORDER BY
    CASE s.status
      WHEN 'active'   THEN 1
      WHEN 'trialing' THEN 2
      ELSE                 3
    END,
    s.current_period_end DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN row_to_json(v_row);
  END IF;

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_subscription() TO authenticated;

-- ============================================================
-- get_subscription_with_count()
-- ============================================================
CREATE OR REPLACE FUNCTION get_subscription_with_count()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_uid           UUID;
  v_sub           subscriptions%ROWTYPE;
  v_student_count INT;
BEGIN
  v_uid := auth.uid();

  -- Individual subscription — prefer active/trialing
  SELECT * INTO v_sub
  FROM subscriptions
  WHERE teacher_id = v_uid
  ORDER BY
    CASE status
      WHEN 'active'   THEN 1
      WHEN 'trialing' THEN 2
      ELSE                 3
    END,
    current_period_end DESC
  LIMIT 1;

  IF NOT FOUND THEN
    -- School-level subscription
    SELECT s.* INTO v_sub
    FROM subscriptions s
    JOIN school_members sm ON sm.school_id = s.school_id
    WHERE sm.user_id    = v_uid
      AND s.teacher_id IS NULL
    ORDER BY
      CASE s.status
        WHEN 'active'   THEN 1
        WHEN 'trialing' THEN 2
        ELSE                 3
      END,
      s.current_period_end DESC
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Count active students for individual plans only
  IF v_sub.plan_type = 'individual' THEN
    SELECT COUNT(DISTINCT cm.user_id)
    INTO v_student_count
    FROM class_members cm
    JOIN classes c ON c.id = cm.class_id
    WHERE c.teacher_id = v_uid
      AND c.archived   = false;
  ELSE
    v_student_count := NULL;
  END IF;

  RETURN json_build_object(
    'id',                 v_sub.id,
    'plan_type',          v_sub.plan_type,
    'status',             v_sub.status,
    'current_period_end', v_sub.current_period_end,
    'student_count',      COALESCE(v_student_count, 0),
    'student_limit',      CASE v_sub.plan_type WHEN 'individual' THEN 15  ELSE NULL END,
    'teacher_limit',      CASE v_sub.plan_type WHEN 'individual' THEN 1   ELSE NULL END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_subscription_with_count() TO authenticated;

-- ============================================================
-- check_can_add_student(p_teacher_id UUID)
-- ============================================================
CREATE OR REPLACE FUNCTION check_can_add_student(p_teacher_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_sub           subscriptions%ROWTYPE;
  v_student_count INT;
BEGIN
  -- Individual subscription — prefer active/trialing
  SELECT * INTO v_sub
  FROM subscriptions
  WHERE teacher_id = p_teacher_id
  ORDER BY
    CASE status
      WHEN 'active'   THEN 1
      WHEN 'trialing' THEN 2
      ELSE                 3
    END,
    current_period_end DESC
  LIMIT 1;

  IF NOT FOUND THEN
    -- No individual subscription → school plan or no subscription: no cap
    RETURN TRUE;
  END IF;

  IF v_sub.plan_type <> 'individual' THEN
    RETURN TRUE;
  END IF;

  -- Count current active students for this teacher
  SELECT COUNT(DISTINCT cm.user_id)
  INTO v_student_count
  FROM class_members cm
  JOIN classes c ON c.id = cm.class_id
  WHERE c.teacher_id = p_teacher_id
    AND c.archived   = false;

  RETURN COALESCE(v_student_count, 0) < 15;
END;
$$;

GRANT EXECUTE ON FUNCTION check_can_add_student(UUID) TO authenticated;
