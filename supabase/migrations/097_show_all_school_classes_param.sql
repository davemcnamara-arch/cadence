-- ============================================================
-- MIGRATION 097: Per-request "show all school classes" flag
--
-- The shared_class_visibility DB column is no longer used to
-- gate what get_teacher_classes returns. Instead, a new
-- p_show_all_school parameter lets the caller opt in per
-- request — matching the UI checkbox approach.
--
-- The RLS UPDATE policy is simplified to always allow
-- same-school peer teachers to edit each other's classes,
-- consistent with the no-hierarchy policy.
--
-- Changes:
--   1. Drop old 3-param get_teacher_classes overload
--   2. Create new 4-param version with p_show_all_school
--   3. Simplify RLS UPDATE policy (drop shared_class_visibility check)
-- ============================================================

-- ============================================================
-- 1. Drop old 3-param overload to avoid PGRST203
-- ============================================================
DROP FUNCTION IF EXISTS public.get_teacher_classes(UUID, BOOLEAN, UUID);

-- ============================================================
-- 2. New 4-param get_teacher_classes
--    p_show_all_school = TRUE → return all classes in the school
--    p_show_all_school = FALSE (default) → own classes only
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

  -- Resolve effective school for non-admin show-all requests
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
    -- Admins see all classes (optionally filtered by school)
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
    -- Show-all: return every class in the school ordered by teacher name then class name
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
    -- Default: teacher's own classes only
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
        'student_count', (SELECT COUNT(*) FROM class_members cm WHERE cm.class_id = c.id),
        'pending_count', (SELECT COUNT(*) FROM pending_enrollments pe WHERE pe.class_id = c.id)
      )
      ORDER BY c.created_at DESC
    )
    INTO v_result
    FROM classes c
    JOIN  users u ON u.id = c.teacher_id
    LEFT JOIN schools s ON s.id = c.school_id
    WHERE c.teacher_id = p_teacher_id
      AND (p_include_archived = true OR c.archived = false)
      AND (p_school_id IS NULL OR c.school_id = p_school_id);
  END IF;

  RETURN COALESCE(v_result, '[]'::json);

EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Permission denied%' THEN RAISE; END IF;
    RETURN '[]'::json;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_classes(UUID, BOOLEAN, UUID, BOOLEAN) TO authenticated;

-- ============================================================
-- 3. Simplify UPDATE policy: peer teachers in the same school
--    can always edit each other's classes (no DB flag needed).
-- ============================================================
DROP POLICY IF EXISTS "Peer teachers can update classes in shared schools" ON classes;

CREATE POLICY "Peer teachers can update classes in shared schools" ON classes
FOR UPDATE USING (
  school_id IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin')
  )
  AND teachers_share_school(auth.uid(), teacher_id)
);
