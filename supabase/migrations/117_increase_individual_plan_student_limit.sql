-- ============================================================
-- MIGRATION 117: Increase Individual plan student limit from 15 to 25
--
-- One class is approximately 25 students, so the Individual plan
-- limit has been raised from 15 to 25 students.
--
-- Updates:
--   get_subscription_with_count() – returns student_limit of 25
--   check_can_add_student()       – allows up to 25 students
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
    'student_limit',          CASE v_sub.plan_type WHEN 'individual' THEN 25 ELSE NULL END,
    'teacher_limit',          CASE v_sub.plan_type WHEN 'individual' THEN 1  ELSE NULL END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_subscription_with_count() TO authenticated;

-- ============================================================
-- check_can_add_student(p_teacher_id UUID)
-- Returns TRUE if the teacher can accept another student.
-- Individual plan cap raised from 15 to 25.
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

  RETURN COALESCE(v_student_count, 0) < 25;
END;
$$;

GRANT EXECUTE ON FUNCTION check_can_add_student(UUID) TO authenticated;

-- ============================================================
-- Update join_class_by_code error message for new 25-student limit
-- ============================================================
CREATE OR REPLACE FUNCTION join_class_by_code(
  p_user_id   UUID,
  p_class_code TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_class_id       UUID;
  v_class_name     TEXT;
  v_teacher_id     UUID;
  v_already_member BOOLEAN;
BEGIN
  -- Find the class by code (case-insensitive, non-archived only)
  SELECT id, name, teacher_id
  INTO v_class_id, v_class_name, v_teacher_id
  FROM classes
  WHERE UPPER(class_code) = UPPER(p_class_code)
    AND archived = false
  LIMIT 1;

  IF v_class_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Class not found. Please check the code.'
    );
  END IF;

  -- Check if already a member
  SELECT EXISTS(
    SELECT 1 FROM class_members
    WHERE class_id = v_class_id AND user_id = p_user_id
  ) INTO v_already_member;

  IF v_already_member THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You are already in this class',
      'class_name', v_class_name
    );
  END IF;

  -- Enforce tier-based student limit for Individual-plan teachers
  IF v_teacher_id IS NOT NULL AND NOT check_can_add_student(v_teacher_id) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'This class cannot accept new students. The teacher has reached the 25-student limit for an Individual subscription. Ask your teacher to upgrade to a School subscription for unlimited students.'
    );
  END IF;

  -- Join the class
  INSERT INTO class_members (class_id, user_id, joined_at)
  VALUES (v_class_id, p_user_id, NOW());

  RETURN json_build_object(
    'success', true,
    'message', 'Successfully joined class',
    'class_name', v_class_name,
    'class_id',   v_class_id
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'message', 'An error occurred while joining the class'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION join_class_by_code(UUID, TEXT) TO authenticated;

-- ============================================================
-- Update process_pending_enrollments error message for new limit
-- ============================================================
CREATE OR REPLACE FUNCTION process_pending_enrollments(p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_email      TEXT;
  v_pending         RECORD;
  v_enrolled_count  INTEGER := 0;
  v_skipped_count   INTEGER := 0;
  v_class_names     TEXT[]  := ARRAY[]::TEXT[];
BEGIN
  -- Get user's email
  SELECT email INTO v_user_email
  FROM users
  WHERE id = p_user_id;

  IF v_user_email IS NULL THEN
    RETURN json_build_object(
      'success',        false,
      'message',        'User not found',
      'enrolled_count', 0
    );
  END IF;

  -- Find all pending enrollments whose email matches this user
  FOR v_pending IN
    SELECT pe.id,
           pe.class_id,
           c.name       AS class_name,
           c.teacher_id AS teacher_id
    FROM pending_enrollments pe
    JOIN classes c ON c.id = pe.class_id
    WHERE LOWER(pe.email) = LOWER(v_user_email)
      AND c.archived = false
  LOOP
    -- Skip if already enrolled (shouldn't happen, but be safe)
    IF EXISTS (
      SELECT 1 FROM class_members
      WHERE class_id = v_pending.class_id
        AND user_id   = p_user_id
    ) THEN
      -- Remove stale pending record and move on
      DELETE FROM pending_enrollments WHERE id = v_pending.id;
      CONTINUE;
    END IF;

    -- Enforce the Individual-plan student cap
    IF v_pending.teacher_id IS NOT NULL
       AND NOT check_can_add_student(v_pending.teacher_id)
    THEN
      -- Limit reached: leave the pending record in place so it can
      -- be processed once the teacher upgrades or frees a slot.
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    -- Enroll the student
    INSERT INTO class_members (class_id, user_id, joined_at)
    VALUES (v_pending.class_id, p_user_id, NOW());

    -- Remove the processed pending enrollment
    DELETE FROM pending_enrollments WHERE id = v_pending.id;

    v_enrolled_count := v_enrolled_count + 1;
    v_class_names    := array_append(v_class_names, v_pending.class_name);
  END LOOP;

  RETURN json_build_object(
    'success',        true,
    'enrolled_count', v_enrolled_count,
    'skipped_count',  v_skipped_count,
    'class_names',    v_class_names,
    'message',        CASE
      WHEN v_enrolled_count > 0 AND v_skipped_count > 0
        THEN format(
          'Automatically enrolled in %s class(es). %s class(es) skipped — teacher has reached the student limit.',
          v_enrolled_count, v_skipped_count
        )
      WHEN v_enrolled_count > 0
        THEN format('Automatically enrolled in %s class(es)', v_enrolled_count)
      WHEN v_skipped_count > 0
        THEN format(
          '%s class(es) could not be joined — the teacher has reached the 25-student limit for an Individual subscription.',
          v_skipped_count
        )
      ELSE 'No pending enrollments found'
    END
  );
END;
$$;

-- Re-grant
GRANT EXECUTE ON FUNCTION process_pending_enrollments(UUID) TO authenticated;
