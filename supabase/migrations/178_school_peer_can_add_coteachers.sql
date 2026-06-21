-- ============================================================
-- MIGRATION 178: Allow any school teacher to add co-teachers
--
-- Previously, only the class owner or admin could add co-teachers.
-- This migration relaxes that to allow any teacher at the same
-- school as the class to add co-teachers from the school.
--
-- Updated functions:
--   - get_class_co_teachers() — school peers can now view the list
--   - add_co_teacher()        — school peers can now add co-teachers
--   - add_pending_co_teacher() — school peers can now add pending co-teachers
-- ============================================================


-- ============================================================
-- 1. get_class_co_teachers
--    Add school peer access (was: owner or co-teacher or admin)
-- ============================================================
CREATE OR REPLACE FUNCTION get_class_co_teachers(p_class_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result       JSON;
  v_class_owner  UUID;
BEGIN
  SELECT teacher_id INTO v_class_owner FROM classes WHERE id = p_class_id;

  IF v_class_owner IS NULL THEN
    RETURN '[]'::json;
  END IF;

  -- Allow: class owner, co-teacher, admin, or any teacher at the same school
  IF NOT is_class_teacher_or_coteacher(p_class_id)
     AND NOT is_admin()
     AND NOT teachers_share_school(auth.uid(), v_class_owner) THEN
    RETURN '[]'::json;
  END IF;

  SELECT COALESCE(
    json_agg(
      json_build_object(
        'teacher_id', combined.teacher_id,
        'name',       combined.display_name,
        'email',      combined.email,
        'added_at',   combined.added_at,
        'is_pending', combined.is_pending
      )
      ORDER BY combined.is_pending ASC, combined.display_name ASC
    ),
    '[]'::json
  )
  INTO v_result
  FROM (
    -- Active co-teachers
    SELECT
      u.id                     AS teacher_id,
      u.name                   AS display_name,
      u.email,
      ct.added_at,
      false                    AS is_pending
    FROM class_co_teachers ct
    JOIN users u ON u.id = ct.teacher_id
    WHERE ct.class_id = p_class_id

    UNION ALL

    -- Pending co-teachers (not yet signed up)
    SELECT
      NULL::UUID               AS teacher_id,
      COALESCE(pra.name, pct.email) AS display_name,
      pct.email,
      pct.added_at,
      true                     AS is_pending
    FROM pending_class_co_teachers pct
    LEFT JOIN pre_registered_accounts pra ON lower(pra.email) = lower(pct.email)
    WHERE pct.class_id = p_class_id
  ) combined;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_class_co_teachers(UUID) TO authenticated;


-- ============================================================
-- 2. add_co_teacher
--    Allow any school peer to add co-teachers (was: owner/admin only)
-- ============================================================
CREATE OR REPLACE FUNCTION add_co_teacher(p_class_id UUID, p_teacher_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      UUID := auth.uid();
  v_class_owner_id UUID;
BEGIN
  SELECT teacher_id INTO v_class_owner_id FROM classes WHERE id = p_class_id;

  IF v_class_owner_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  -- Allow: class owner, admin, or any teacher at the same school as the class
  IF v_caller_id != v_class_owner_id
     AND NOT is_admin()
     AND NOT teachers_share_school(v_caller_id, v_class_owner_id) THEN
    RETURN json_build_object('success', false, 'message', 'Only teachers at the same school can add co-teachers');
  END IF;

  IF p_teacher_id = v_class_owner_id THEN
    RETURN json_build_object('success', false, 'message', 'The class owner cannot be added as a co-teacher');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_teacher_id AND role IN ('teacher', 'admin')) THEN
    RETURN json_build_object('success', false, 'message', 'That user is not a teacher');
  END IF;

  -- The teacher being added must share a school with the class owner
  IF NOT is_admin() AND NOT teachers_share_school(v_class_owner_id, p_teacher_id) THEN
    RETURN json_build_object('success', false, 'message', 'Co-teachers must be at the same school');
  END IF;

  INSERT INTO class_co_teachers (class_id, teacher_id)
  VALUES (p_class_id, p_teacher_id)
  ON CONFLICT (class_id, teacher_id) DO NOTHING;

  RETURN json_build_object('success', true, 'message', 'Co-teacher added');
END;
$$;

GRANT EXECUTE ON FUNCTION add_co_teacher(UUID, UUID) TO authenticated;


-- ============================================================
-- 3. add_pending_co_teacher
--    Allow any school peer to add pending co-teachers (was: owner/admin only)
-- ============================================================
CREATE OR REPLACE FUNCTION add_pending_co_teacher(
  p_class_id UUID,
  p_email    TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      UUID := auth.uid();
  v_class_owner_id UUID;
  v_normalized     TEXT := LOWER(TRIM(p_email));
BEGIN
  IF v_normalized = '' OR v_normalized IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Email is required');
  END IF;

  SELECT teacher_id INTO v_class_owner_id FROM classes WHERE id = p_class_id;

  IF v_class_owner_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  -- Allow: class owner, admin, or any teacher at the same school as the class
  IF v_caller_id != v_class_owner_id
     AND NOT is_admin()
     AND NOT teachers_share_school(v_caller_id, v_class_owner_id) THEN
    RETURN json_build_object('success', false, 'message', 'Only teachers at the same school can add co-teachers');
  END IF;

  -- If this email already belongs to an active user, reject — use add_co_teacher instead
  IF EXISTS (SELECT 1 FROM users WHERE lower(email) = v_normalized AND role IN ('teacher', 'admin')) THEN
    RETURN json_build_object('success', false, 'message', 'That teacher has already signed up — select them from the active teacher list');
  END IF;

  INSERT INTO pending_class_co_teachers (class_id, email)
  VALUES (p_class_id, v_normalized)
  ON CONFLICT (class_id, email) DO NOTHING;

  RETURN json_build_object('success', true, 'message', 'Co-teacher invite added — they will have access once they log in');
END;
$$;

GRANT EXECUTE ON FUNCTION add_pending_co_teacher(UUID, TEXT) TO authenticated;
