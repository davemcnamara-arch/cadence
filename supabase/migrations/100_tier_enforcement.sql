-- ============================================================
-- MIGRATION 100: Tier enforcement for student/teacher limits
--
-- Individual plan: 1 teacher, up to 25 students total (raised from 15 in migration 117)
-- School plan: unlimited teachers and students
--
-- New functions:
--   get_teacher_student_count()  – total active students across
--                                  all classes owned by the caller
--   get_subscription_with_count() – subscription row + student
--                                   count in one call (used by
--                                   the dashboard plan banner)
-- ============================================================

-- ============================================================
-- Helper: count total active students across all of a teacher's
-- non-archived classes.  Uses auth.uid() as the teacher.
-- ============================================================
CREATE OR REPLACE FUNCTION get_teacher_student_count()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_uid   UUID;
  v_count INT;
BEGIN
  v_uid := auth.uid();

  SELECT COUNT(DISTINCT cm.user_id)
  INTO v_count
  FROM class_members cm
  JOIN classes c ON c.id = cm.class_id
  WHERE c.teacher_id = v_uid
    AND c.archived   = false;

  RETURN COALESCE(v_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION get_teacher_student_count() TO authenticated;

-- ============================================================
-- get_subscription_with_count()
-- Returns the caller's subscription details together with their
-- current total student count.  The frontend uses this to:
--   1. Show the plan-limits banner
--   2. Decide whether to allow adding more students
-- ============================================================
CREATE OR REPLACE FUNCTION get_subscription_with_count()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_uid          UUID;
  v_sub          subscriptions%ROWTYPE;
  v_student_count INT;
BEGIN
  v_uid := auth.uid();

  -- Individual subscription for this teacher
  SELECT * INTO v_sub
  FROM subscriptions
  WHERE teacher_id = v_uid
  LIMIT 1;

  IF NOT FOUND THEN
    -- School-level subscription for any school the caller belongs to
    SELECT s.* INTO v_sub
    FROM subscriptions s
    JOIN school_members sm ON sm.school_id = s.school_id
    WHERE sm.user_id = v_uid
      AND s.teacher_id IS NULL
    LIMIT 1;
  END IF;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Count active students for individual plans only
  -- (saves a query for school plans where no cap applies)
  IF v_sub.plan_type = 'individual' THEN
    SELECT COUNT(DISTINCT cm.user_id)
    INTO v_student_count
    FROM class_members cm
    JOIN classes c ON c.id = cm.class_id
    WHERE c.teacher_id = v_uid
      AND c.archived   = false;
  ELSE
    v_student_count := NULL;   -- no cap, no need to count
  END IF;

  RETURN json_build_object(
    'id',                     v_sub.id,
    'plan_type',              v_sub.plan_type,
    'status',                 v_sub.status,
    'current_period_end',     v_sub.current_period_end,
    'student_count',          COALESCE(v_student_count, 0),
    'student_limit',          CASE v_sub.plan_type WHEN 'individual' THEN 15 ELSE NULL END,
    'teacher_limit',          CASE v_sub.plan_type WHEN 'individual' THEN 1  ELSE NULL END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_subscription_with_count() TO authenticated;

-- ============================================================
-- check_can_add_student(p_class_id UUID)
-- Server-side gate used inside join_class_by_code and the
-- pending-enrollment processor.
-- Returns TRUE  → OK to add
--         FALSE → individual plan limit reached
-- ============================================================
CREATE OR REPLACE FUNCTION check_can_add_student(p_teacher_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_sub          subscriptions%ROWTYPE;
  v_student_count INT;
BEGIN
  -- Individual subscription?
  SELECT * INTO v_sub
  FROM subscriptions
  WHERE teacher_id = p_teacher_id
  LIMIT 1;

  IF NOT FOUND THEN
    -- School-level subscription: no cap
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
