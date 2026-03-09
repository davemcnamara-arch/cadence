-- ============================================================
-- MIGRATION 089: Fix class school_name join for multi-school teachers
--
-- Problem: get_teacher_classes() and get_student_classes() derived
-- the school_name by joining via school_members on the teacher's
-- user_id. When a teacher belongs to more than one school this
-- join is non-deterministic and can return any of the teacher's
-- schools, causing the wrong label to appear on class cards.
--
-- get_school_dashboard() (migration 084) correctly counts classes
-- by c.school_id, so the label mismatch produces "0 active classes"
-- in the dashboard while the class list shows the wrong school name.
--
-- Fix: join schools directly via c.school_id in both functions.
-- ============================================================

-- ============================================================
-- 1. Fix get_teacher_classes()
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_teacher_classes(
  p_teacher_id UUID,
  p_include_archived BOOLEAN DEFAULT false
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
    -- Admin: all classes; join school via c.school_id
    SELECT json_agg(
      json_build_object(
        'id',            c.id,
        'name',          c.name,
        'year_level',    c.year_level,
        'class_code',    c.class_code,
        'teacher_id',    c.teacher_id,
        'teacher_name',  u.name,
        'school_name',   s.name,
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
    WHERE (p_include_archived = true OR c.archived = false);
  ELSE
    -- Teacher: own classes only; join school via c.school_id
    SELECT json_agg(
      json_build_object(
        'id',            c.id,
        'name',          c.name,
        'year_level',    c.year_level,
        'class_code',    c.class_code,
        'teacher_id',    c.teacher_id,
        'school_name',   s.name,
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
      AND (p_include_archived = true OR c.archived = false);
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

-- ============================================================
-- 2. Fix get_student_classes()
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_student_classes()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_result  JSON;
BEGIN
  v_user_id := auth.uid();

  SELECT json_agg(
    json_build_object(
      'class_id',   cm.class_id,
      'joined_at',  cm.joined_at,
      'class_name', c.name,
      'class_code', c.class_code,
      'year_level', c.year_level,
      'created_at', c.created_at,
      'school_name', s.name
    )
    ORDER BY cm.joined_at DESC
  ) INTO v_result
  FROM class_members cm
  JOIN  classes c ON c.id = cm.class_id
  LEFT JOIN schools s ON s.id = c.school_id
  WHERE cm.user_id = v_user_id;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_classes(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_student_classes()               TO authenticated;
