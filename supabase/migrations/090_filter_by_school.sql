-- ============================================================
-- MIGRATION 090: Add school filtering to teacher RPCs
--
-- Adds optional p_school_id parameter to:
--   get_teacher_classes   - filter classes by school
--   search_teacher_students - filter students by school
--
-- When p_school_id is NULL, behaviour is unchanged (return all).
-- ============================================================

-- ============================================================
-- 1. get_teacher_classes with optional school filter
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_teacher_classes(
  p_teacher_id      UUID,
  p_include_archived BOOLEAN DEFAULT false,
  p_school_id       UUID    DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_is_admin        BOOLEAN;
  v_result          JSON;
BEGIN
  v_current_user_id := auth.uid();
  v_is_admin := is_admin();

  -- Authorization: must be requesting own classes OR be an admin
  IF v_current_user_id != p_teacher_id AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Permission denied: You can only view your own classes';
  END IF;

  IF v_is_admin THEN
    SELECT json_agg(
      json_build_object(
        'id',            c.id,
        'name',          c.name,
        'year_level',    c.year_level,
        'class_code',    c.class_code,
        'teacher_id',    c.teacher_id,
        'teacher_name',  u.name,
        'school_name',   s.name,
        'school_id',     c.school_id,
        'created_at',    c.created_at,
        'archived',      c.archived,
        'student_count', (
          SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = c.id
        ),
        'pending_count', (
          SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = c.id
        )
      )
      ORDER BY u.name, c.created_at DESC
    )
    INTO v_result
    FROM classes c
    JOIN  users u ON u.id = c.teacher_id
    LEFT JOIN schools s ON s.id = c.school_id
    WHERE (p_include_archived = true OR c.archived = false)
      AND (p_school_id IS NULL OR c.school_id = p_school_id);
  ELSE
    SELECT json_agg(
      json_build_object(
        'id',            c.id,
        'name',          c.name,
        'year_level',    c.year_level,
        'class_code',    c.class_code,
        'teacher_id',    c.teacher_id,
        'school_name',   s.name,
        'school_id',     c.school_id,
        'created_at',    c.created_at,
        'archived',      c.archived,
        'student_count', (
          SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = c.id
        ),
        'pending_count', (
          SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = c.id
        )
      )
      ORDER BY c.created_at DESC
    )
    INTO v_result
    FROM classes c
    LEFT JOIN schools s ON s.id = c.school_id
    WHERE c.teacher_id = p_teacher_id
      AND (p_include_archived = true OR c.archived = false)
      AND (p_school_id IS NULL OR c.school_id = p_school_id);
  END IF;

  RETURN COALESCE(v_result, '[]'::json);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    RETURN '[]'::json;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_classes(UUID, BOOLEAN, UUID) TO authenticated;

-- ============================================================
-- 2. search_teacher_students with optional school filter
-- ============================================================
CREATE OR REPLACE FUNCTION search_teacher_students(
  p_school_id UUID DEFAULT NULL
)
RETURNS TABLE (
  user_id    UUID,
  name       TEXT,
  email      TEXT,
  class_id   UUID,
  class_name TEXT,
  joined_at  TIMESTAMPTZ,
  is_pending BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF is_admin() THEN
    -- Active students in any class (optionally scoped to school)
    RETURN QUERY
    SELECT
      u.id AS user_id,
      u.name,
      u.email,
      c.id AS class_id,
      c.name AS class_name,
      cm.joined_at,
      FALSE AS is_pending
    FROM users u
    INNER JOIN class_members cm ON u.id = cm.user_id
    INNER JOIN classes c ON cm.class_id = c.id
    WHERE c.archived IS NOT TRUE
      AND (p_school_id IS NULL OR c.school_id = p_school_id);

    -- Students not linked to any class (only when no school filter)
    IF p_school_id IS NULL THEN
      RETURN QUERY
      SELECT
        u.id AS user_id,
        u.name,
        u.email,
        NULL::UUID AS class_id,
        'No Class'::TEXT AS class_name,
        u.created_at AS joined_at,
        FALSE AS is_pending
      FROM users u
      WHERE u.role = 'student'
        AND NOT EXISTS (
          SELECT 1 FROM class_members cm WHERE cm.user_id = u.id
        );
    END IF;

    -- Pending enrollments (optionally scoped to school)
    RETURN QUERY
    SELECT
      NULL::UUID AS user_id,
      SPLIT_PART(pe.email, '@', 1) AS name,
      pe.email,
      c.id AS class_id,
      c.name AS class_name,
      pe.created_at AS joined_at,
      TRUE AS is_pending
    FROM pending_enrollments pe
    INNER JOIN classes c ON pe.class_id = c.id
    WHERE c.archived IS NOT TRUE
      AND (p_school_id IS NULL OR c.school_id = p_school_id);
  ELSE
    -- Active students in teacher's classes (optionally scoped to school)
    RETURN QUERY
    SELECT
      u.id AS user_id,
      u.name,
      u.email,
      c.id AS class_id,
      c.name AS class_name,
      cm.joined_at,
      FALSE AS is_pending
    FROM users u
    INNER JOIN class_members cm ON u.id = cm.user_id
    INNER JOIN classes c ON cm.class_id = c.id
    WHERE c.teacher_id = auth.uid()
      AND c.archived IS NOT TRUE
      AND (p_school_id IS NULL OR c.school_id = p_school_id);

    -- Pending enrollments for teacher's classes (optionally scoped to school)
    RETURN QUERY
    SELECT
      NULL::UUID AS user_id,
      SPLIT_PART(pe.email, '@', 1) AS name,
      pe.email,
      c.id AS class_id,
      c.name AS class_name,
      pe.created_at AS joined_at,
      TRUE AS is_pending
    FROM pending_enrollments pe
    INNER JOIN classes c ON pe.class_id = c.id
    WHERE c.teacher_id = auth.uid()
      AND c.archived IS NOT TRUE
      AND (p_school_id IS NULL OR c.school_id = p_school_id);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION search_teacher_students(UUID) TO authenticated;
