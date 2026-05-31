-- ============================================================
-- MIGRATION 172: Fix subscription lookup when auto-trial and
--                paid school subscription coexist
-- ============================================================
-- The auto-trial (migration 168/170) inserts a row linked to
-- the teacher (teacher_id = v_uid, school_id NULL, trialing).
-- A paid school subscription is linked to the school
-- (school_id IS NOT NULL, teacher_id NULL, active).
--
-- get_my_subscription() and get_subscription_with_count() both
-- queried teacher-linked rows first and returned early if found,
-- so the active school subscription was never seen.
--
-- Fix: UNION both sources then apply the status-preference
-- ordering across all rows before LIMIT 1.
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

  SELECT combined.* INTO v_row
  FROM (
    SELECT s.* FROM subscriptions s
    WHERE s.teacher_id = v_uid
    UNION ALL
    SELECT s.* FROM subscriptions s
    JOIN school_members sm ON sm.school_id = s.school_id
    WHERE sm.user_id = v_uid
      AND s.teacher_id IS NULL
  ) combined
  ORDER BY
    CASE combined.status
      WHEN 'active'   THEN 1
      WHEN 'trialing' THEN 2
      ELSE                 3
    END,
    combined.current_period_end DESC
  LIMIT 1;

  IF FOUND THEN
    RETURN row_to_json(v_row);
  END IF;

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_subscription() TO authenticated;


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

  SELECT combined.* INTO v_sub
  FROM (
    SELECT s.* FROM subscriptions s
    WHERE s.teacher_id = v_uid
    UNION ALL
    SELECT s.* FROM subscriptions s
    JOIN school_members sm ON sm.school_id = s.school_id
    WHERE sm.user_id = v_uid
      AND s.teacher_id IS NULL
  ) combined
  ORDER BY
    CASE combined.status
      WHEN 'active'   THEN 1
      WHEN 'trialing' THEN 2
      ELSE                 3
    END,
    combined.current_period_end DESC
  LIMIT 1;

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
