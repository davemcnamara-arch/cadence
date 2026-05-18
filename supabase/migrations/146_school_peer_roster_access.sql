-- ============================================================
-- MIGRATION 146: Allow same-school peers to view class rosters
--
-- When a teacher uses "Show all school classes" they can see
-- a colleague's class card, open it, but get_class_students
-- and get_pending_enrollments denied access because neither
-- function checked for same-school membership.
--
-- Fix: add a teachers_share_school() branch to both functions
-- so that any teacher at the same school can read the roster
-- and pending enrollments of a peer's class — matching the
-- existing RLS UPDATE policy introduced in migration 097.
-- ============================================================

-- ============================================================
-- 1. get_class_students
--    Old: admin OR teacher/co-teacher OR class member
--    New: + same-school peer teacher
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_class_students(p_class_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_is_authorized   BOOLEAN;
  v_class_teacher   UUID;
  v_result          JSON;
BEGIN
  v_current_user_id := auth.uid();

  -- Resolve the class owner so we can check school membership
  SELECT teacher_id INTO v_class_teacher
  FROM classes
  WHERE id = p_class_id;

  SELECT (
    is_admin()
    OR is_class_teacher_or_coteacher(p_class_id)
    OR EXISTS (
      SELECT 1 FROM class_members cm
      WHERE cm.class_id = p_class_id AND cm.user_id = v_current_user_id
    )
    OR (
      v_class_teacher IS NOT NULL
      AND teachers_share_school(v_current_user_id, v_class_teacher)
    )
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this class';
  END IF;

  SELECT json_agg(
    json_build_object(
      'id',        cm.id,
      'class_id',  cm.class_id,
      'user_id',   cm.user_id,
      'joined_at', cm.joined_at,
      'users', json_build_object(
        'id',    u.id,
        'name',  u.name,
        'email', u.email
      ),
      'student_progress', (
        SELECT json_agg(
          json_build_object(
            'instrument_id',          sp.instrument_id,
            'current_level',          sp.current_level,
            'current_branch',         sp.current_branch,
            'custom_instrument_name', sp.custom_instrument_name
          )
        )
        FROM student_progress sp
        WHERE sp.user_id = u.id
      )
    )
    ORDER BY cm.joined_at ASC
  )
  INTO v_result
  FROM class_members cm
  JOIN users u ON u.id = cm.user_id
  WHERE cm.class_id = p_class_id;

  RETURN COALESCE(v_result, '[]'::json);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    RETURN '[]'::json;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_class_students(UUID) TO authenticated;


-- ============================================================
-- 2. get_pending_enrollments
--    Old: admin OR teacher/co-teacher
--    New: + same-school peer teacher
-- ============================================================
CREATE OR REPLACE FUNCTION get_pending_enrollments(p_class_id UUID)
RETURNS TABLE (
  id         UUID,
  email      TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_class_teacher UUID;
BEGIN
  SELECT teacher_id INTO v_class_teacher
  FROM classes
  WHERE id = p_class_id;

  IF NOT is_admin()
     AND NOT is_class_teacher_or_coteacher(p_class_id)
     AND NOT (
       v_class_teacher IS NOT NULL
       AND teachers_share_school(auth.uid(), v_class_teacher)
     )
  THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT pe.id, pe.email, pe.created_at
  FROM pending_enrollments pe
  WHERE pe.class_id = p_class_id
  ORDER BY pe.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_pending_enrollments(UUID) TO authenticated;
