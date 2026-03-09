-- Migration: Add school_name to class queries and create get_student_classes RPC
-- This allows school labels to appear alongside class labels throughout the UI

-- ============================================================
-- 1. Update get_teacher_classes to include school_name
--    (derived from the teacher's school membership)
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
  v_is_admin BOOLEAN;
  v_result JSON;
BEGIN
  v_current_user_id := auth.uid();
  v_is_admin := is_admin();

  -- Authorization: must be requesting own classes OR be an admin
  IF v_current_user_id != p_teacher_id AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Permission denied: You can only view your own classes';
  END IF;

  -- For admins, return ALL classes (ignore p_teacher_id filter)
  -- Include teacher_name and school_name so admin can see context
  IF v_is_admin THEN
    SELECT json_agg(
      json_build_object(
        'id', c.id,
        'name', c.name,
        'year_level', c.year_level,
        'class_code', c.class_code,
        'teacher_id', c.teacher_id,
        'teacher_name', u.name,
        'school_name', s.name,
        'created_at', c.created_at,
        'archived', c.archived,
        'student_count', (
          SELECT COUNT(*)
          FROM class_members cm
          WHERE cm.class_id = c.id
        ),
        'pending_count', (
          SELECT COUNT(*)
          FROM pending_enrollments pe
          WHERE pe.class_id = c.id
        )
      )
      ORDER BY u.name, c.created_at DESC
    )
    INTO v_result
    FROM classes c
    JOIN users u ON u.id = c.teacher_id
    LEFT JOIN school_members sm ON sm.user_id = c.teacher_id
    LEFT JOIN schools s ON s.id = sm.school_id
    WHERE (p_include_archived = true OR c.archived = false);
  ELSE
    -- Teacher: return only their own classes, with their school name
    SELECT json_agg(
      json_build_object(
        'id', c.id,
        'name', c.name,
        'year_level', c.year_level,
        'class_code', c.class_code,
        'teacher_id', c.teacher_id,
        'school_name', s.name,
        'created_at', c.created_at,
        'archived', c.archived,
        'student_count', (
          SELECT COUNT(*)
          FROM class_members cm
          WHERE cm.class_id = c.id
        ),
        'pending_count', (
          SELECT COUNT(*)
          FROM pending_enrollments pe
          WHERE pe.class_id = c.id
        )
      )
      ORDER BY c.created_at DESC
    )
    INTO v_result
    FROM classes c
    LEFT JOIN school_members sm ON sm.user_id = c.teacher_id
    LEFT JOIN schools s ON s.id = sm.school_id
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
-- 2. Create get_student_classes RPC
--    Returns the calling student's class memberships,
--    including the school_name of each class's teacher.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_student_classes()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_result JSON;
BEGIN
  v_user_id := auth.uid();

  SELECT json_agg(
    json_build_object(
      'class_id', cm.class_id,
      'joined_at', cm.joined_at,
      'class_name', c.name,
      'class_code', c.class_code,
      'year_level', c.year_level,
      'created_at', c.created_at,
      'school_name', s.name
    )
    ORDER BY cm.joined_at DESC
  ) INTO v_result
  FROM class_members cm
  JOIN classes c ON c.id = cm.class_id
  LEFT JOIN school_members sm ON sm.user_id = c.teacher_id
  LEFT JOIN schools s ON s.id = sm.school_id
  WHERE cm.user_id = v_user_id;

  RETURN COALESCE(v_result, '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_classes() TO authenticated;
