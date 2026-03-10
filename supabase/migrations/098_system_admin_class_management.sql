-- ============================================================
-- MIGRATION 098: System admin class management
--
-- Elevates the 'admin' role to a true system-wide admin:
--   1. admin_delete_class(p_class_id) – SECURITY DEFINER RPC
--      so the system admin can delete any class regardless of
--      RLS on the classes table.
--   2. admin_get_school_classes(p_school_id) – returns all
--      classes (including archived) for a given school so the
--      admin school dashboard can show a full class list.
-- ============================================================

-- ── 1. Delete any class (system-admin only) ──────────────────
CREATE OR REPLACE FUNCTION admin_delete_class(p_class_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_class_name TEXT;
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
  END IF;

  SELECT name INTO v_class_name FROM classes WHERE id = p_class_id;

  IF v_class_name IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  -- Cascades to class_members, pending_enrollments, etc.
  DELETE FROM classes WHERE id = p_class_id;

  RETURN json_build_object('success', true, 'message', 'Class deleted');

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_delete_class(UUID) TO authenticated;

-- ── 2. Get all classes for a school (system-admin only) ──────
CREATE OR REPLACE FUNCTION admin_get_school_classes(
  p_school_id        UUID,
  p_include_archived BOOLEAN DEFAULT true
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSON;
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
  END IF;

  SELECT json_agg(
    json_build_object(
      'id',            c.id,
      'name',          c.name,
      'year_level',    c.year_level,
      'class_code',    c.class_code,
      'teacher_id',    c.teacher_id,
      'teacher_name',  u.name,
      'school_id',     c.school_id,
      'created_at',    c.created_at,
      'archived',      c.archived,
      'student_count', (SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = c.id),
      'pending_count', (SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = c.id)
    )
    ORDER BY u.name, c.name
  )
  INTO v_result
  FROM classes c
  JOIN  users u ON u.id = c.teacher_id
  WHERE c.school_id = p_school_id
    AND (p_include_archived OR c.archived = false);

  RETURN json_build_object(
    'success', true,
    'classes', COALESCE(v_result, '[]'::json)
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_school_classes(UUID, BOOLEAN) TO authenticated;
