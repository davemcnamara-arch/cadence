-- ============================================================
-- MIGRATION 111: Fix get_all_schools subscription lookup
--
-- The previous version only joined subscriptions on school_id.
-- Individual-plan subscriptions have teacher_id set and
-- school_id NULL, so they were missed.
--
-- New priority order per school:
--   1. School-level subscription  (school_id = s.id)
--   2. Individual subscription for the school creator
--      (teacher_id = s.created_by, school_id IS NULL)
-- ============================================================

CREATE OR REPLACE FUNCTION get_all_schools()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID;
  v_user_role TEXT;
  v_result    JSON;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  SELECT json_build_object(
    'success', true,
    'schools', COALESCE((
      SELECT json_agg(
        json_build_object(
          'id',                  s.id,
          'name',                s.name,
          'join_code',           s.join_code,
          'created_at',          s.created_at,
          'owner_email',         owner.email,
          'teacher_count', (
            SELECT COUNT(*) FROM school_members sm WHERE sm.school_id = s.id
          ),
          'class_count', (
            SELECT COUNT(*)
            FROM classes c
            WHERE c.school_id = s.id AND c.archived = false
          ),
          'student_count', (
            SELECT COUNT(*) FROM school_students ss WHERE ss.school_id = s.id
          ),
          'subscription_id',     sub.id,
          'subscription_status', sub.status,
          'plan_type',           sub.plan_type,
          'current_period_end',  sub.current_period_end
        )
        ORDER BY s.created_at ASC
      )
      FROM schools s
      LEFT JOIN users owner ON owner.id = s.created_by
      LEFT JOIN LATERAL (
        -- Pick the most relevant subscription:
        -- priority 1 = school-level, priority 2 = creator's individual plan
        SELECT id, status, plan_type, current_period_end
        FROM (
          SELECT id, status, plan_type, current_period_end, 1 AS priority, created_at
          FROM subscriptions
          WHERE school_id = s.id

          UNION ALL

          SELECT id, status, plan_type, current_period_end, 2 AS priority, created_at
          FROM subscriptions
          WHERE teacher_id = s.created_by
            AND school_id IS NULL
        ) all_subs
        ORDER BY priority ASC, created_at DESC
        LIMIT 1
      ) sub ON true
    ), '[]'::JSON)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_schools() TO authenticated;
