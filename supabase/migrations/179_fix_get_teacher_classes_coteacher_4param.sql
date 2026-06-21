-- ============================================================
-- MIGRATION 179: Fix 4-param get_teacher_classes to include
--                co-taught classes and is_co_teacher field
--
-- Two overloads exist:
--   - 3-param (migration 144): has co-teacher UNION but no p_show_all_school
--   - 4-param (migration 097): has p_show_all_school but only returns own
--                               classes in the ELSE branch — missing co-taught
--
-- loadClasses() always passes p_show_all_school so it hits the 4-param
-- version, which never returns co-taught classes. This migration updates
-- the 4-param ELSE branch to UNION in co-taught classes and adds the
-- is_co_teacher field consistently across all branches.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_teacher_classes(
  p_teacher_id       UUID,
  p_include_archived BOOLEAN DEFAULT false,
  p_school_id        UUID    DEFAULT NULL,
  p_show_all_school  BOOLEAN DEFAULT false
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id     UUID;
  v_is_admin            BOOLEAN;
  v_result              JSON;
  v_effective_school_id UUID;
BEGIN
  v_current_user_id := auth.uid();
  v_is_admin := is_admin();

  IF v_current_user_id != p_teacher_id AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Permission denied: You can only view your own classes';
  END IF;

  -- Resolve effective school for show-all requests
  IF p_show_all_school AND NOT v_is_admin THEN
    IF p_school_id IS NOT NULL THEN
      v_effective_school_id := p_school_id;
    ELSE
      SELECT sm.school_id INTO v_effective_school_id
      FROM school_members sm
      WHERE sm.user_id = p_teacher_id
      ORDER BY sm.joined_at ASC
      LIMIT 1;
    END IF;
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
        'is_co_teacher', false,
        'student_count', (SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = c.id),
        'pending_count', (SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = c.id)
      )
      ORDER BY u.name, c.created_at DESC
    )
    INTO v_result
    FROM classes c
    JOIN  users u ON u.id = c.teacher_id
    LEFT JOIN schools s ON s.id = c.school_id
    WHERE (p_include_archived = true OR c.archived = false)
      AND (p_school_id IS NULL OR c.school_id = p_school_id);

  ELSIF p_show_all_school AND v_effective_school_id IS NOT NULL THEN
    -- Show-all: every class in the school
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
        'is_co_teacher', (c.teacher_id != p_teacher_id),
        'student_count', (SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = c.id),
        'pending_count', (SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = c.id)
      )
      ORDER BY u.name, c.name
    )
    INTO v_result
    FROM classes c
    JOIN  users u ON u.id = c.teacher_id
    LEFT JOIN schools s ON s.id = c.school_id
    WHERE c.school_id = v_effective_school_id
      AND (p_include_archived = true OR c.archived = false);

  ELSE
    -- Default: own classes UNION co-taught classes
    SELECT json_agg(
      json_build_object(
        'id',            combined.id,
        'name',          combined.name,
        'year_level',    combined.year_level,
        'class_code',    combined.class_code,
        'teacher_id',    combined.teacher_id,
        'teacher_name',  combined.teacher_name,
        'school_name',   combined.school_name,
        'school_id',     combined.school_id,
        'created_at',    combined.created_at,
        'archived',      combined.archived,
        'is_co_teacher', combined.is_co_teacher,
        'student_count', (SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = combined.id),
        'pending_count', (SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = combined.id)
      )
      ORDER BY combined.is_co_teacher ASC, combined.created_at DESC
    )
    INTO v_result
    FROM (
      -- Own classes
      SELECT c.id, c.name, c.year_level, c.class_code, c.teacher_id,
             u.name AS teacher_name, s.name AS school_name, c.school_id,
             c.created_at, c.archived, false AS is_co_teacher
      FROM classes c
      JOIN users u ON u.id = c.teacher_id
      LEFT JOIN schools s ON s.id = c.school_id
      WHERE c.teacher_id = p_teacher_id
        AND (p_include_archived = true OR c.archived = false)
        AND (p_school_id IS NULL OR c.school_id = p_school_id)

      UNION ALL

      -- Co-taught classes
      SELECT c.id, c.name, c.year_level, c.class_code, c.teacher_id,
             u.name AS teacher_name, s.name AS school_name, c.school_id,
             c.created_at, c.archived, true AS is_co_teacher
      FROM classes c
      JOIN users u ON u.id = c.teacher_id
      LEFT JOIN schools s ON s.id = c.school_id
      JOIN class_co_teachers cct ON cct.class_id = c.id AND cct.teacher_id = p_teacher_id
      WHERE (p_include_archived = true OR c.archived = false)
        AND (p_school_id IS NULL OR c.school_id = p_school_id)
    ) combined;
  END IF;

  RETURN COALESCE(v_result, '[]'::json);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Permission denied%' THEN RAISE; END IF;
    RETURN '[]'::json;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_classes(UUID, BOOLEAN, UUID, BOOLEAN) TO authenticated;
