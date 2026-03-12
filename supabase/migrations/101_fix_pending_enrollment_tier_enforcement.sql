-- ============================================================
-- MIGRATION 101: Enforce tier limits in process_pending_enrollments
--
-- process_pending_enrollments (migration 034) was created before
-- the subscription tier system (migrations 099-100).  It enrolled
-- students directly without calling check_can_add_student(), so a
-- teacher who pre-added emails could exceed the 15-student cap on
-- an Individual plan simply by having those students log in.
--
-- This migration replaces the function so that each pending
-- enrollment is subject to the same limit gate used by
-- join_class_by_code.
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

    -- Enforce the Individual-plan 15-student cap
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
          '%s class(es) could not be joined — the teacher has reached the 15-student limit for an Individual subscription.',
          v_skipped_count
        )
      ELSE 'No pending enrollments found'
    END
  );
END;
$$;

-- Re-grant (function is already granted in migration 034; this is idempotent)
GRANT EXECUTE ON FUNCTION process_pending_enrollments(UUID) TO authenticated;
