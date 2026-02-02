-- Fix admin class permissions
-- 1. Restore admin support in get_teacher_classes (lost in migration 045)
-- 2. Add RLS policies for admin to INSERT/UPDATE/DELETE classes

-- ============================================================================
-- 1. Fix get_teacher_classes to restore admin support WITH pending_count
-- ============================================================================
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
  -- Include teacher_name so admin can see who owns each class
  IF v_is_admin THEN
    SELECT json_agg(
      json_build_object(
        'id', c.id,
        'name', c.name,
        'year_level', c.year_level,
        'class_code', c.class_code,
        'teacher_id', c.teacher_id,
        'teacher_name', u.name,
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
    WHERE (p_include_archived = true OR c.archived = false);
  ELSE
    -- Teacher: return only their own classes
    SELECT json_agg(
      json_build_object(
        'id', c.id,
        'name', c.name,
        'year_level', c.year_level,
        'class_code', c.class_code,
        'teacher_id', c.teacher_id,
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

-- ============================================================================
-- 2. Add admin RLS policies for INSERT/UPDATE/DELETE on classes
-- ============================================================================

-- Drop existing admin policies if they exist to avoid duplicates
DROP POLICY IF EXISTS "Admins can create classes" ON classes;
DROP POLICY IF EXISTS "Admins can update all classes" ON classes;
DROP POLICY IF EXISTS "Admins can delete classes" ON classes;

-- Allow admins to create classes
-- Note: Admin can create a class with themselves as teacher, or potentially
-- assign another teacher (if the UI supports it in the future)
CREATE POLICY "Admins can create classes" ON classes FOR INSERT
  WITH CHECK (is_admin());

-- Allow admins to update any class
CREATE POLICY "Admins can update all classes" ON classes FOR UPDATE
  USING (is_admin());

-- Allow admins to delete any class (for cleanup/moderation purposes)
CREATE POLICY "Admins can delete classes" ON classes FOR DELETE
  USING (is_admin());

-- ============================================================================
-- 3. Add admin policy for class_members DELETE (for removing students)
-- ============================================================================
DROP POLICY IF EXISTS "Admins can delete class members" ON class_members;

CREATE POLICY "Admins can delete class members" ON class_members FOR DELETE
  USING (is_admin());

-- ============================================================================
-- 4. Ensure is_admin() function is using the latest definition
-- ============================================================================
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;
