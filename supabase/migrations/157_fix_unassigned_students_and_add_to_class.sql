-- Migration 157: Fix admin_get_unassigned_students + add admin_get_all_classes + admin_add_student_to_class
--
-- Problem: admin_get_unassigned_students excluded students in archived classes (they still have
-- class_members rows), so those students never appeared as "unassigned" even though their classes
-- are gone. Fix: only exclude students who are in at least one non-archived class.
--
-- Also adds two new admin RPCs needed for the "Add to Class" admin action.

-- 1. Fix admin_get_unassigned_students
CREATE OR REPLACE FUNCTION admin_get_unassigned_students()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  RETURN (
    SELECT COALESCE(json_agg(
      json_build_object(
        'id',            u.id,
        'email',         u.email,
        'name',          u.name,
        'created_at',    u.created_at,
        'last_sign_in',  au.last_sign_in_at
      )
      ORDER BY u.created_at DESC
    ), '[]'::JSON)
    FROM users u
    LEFT JOIN auth.users au ON au.id = u.id
    WHERE u.role = 'student'
      AND NOT EXISTS (
        SELECT 1
        FROM class_members cm
        JOIN classes c ON c.id = cm.class_id
        WHERE cm.user_id = u.id
          AND (c.archived IS NULL OR c.archived = false)
      )
  );
END;
$$;

-- 2. admin_get_all_classes — returns all non-archived classes with teacher + school info
CREATE OR REPLACE FUNCTION admin_get_all_classes()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  RETURN (
    SELECT COALESCE(json_agg(
      json_build_object(
        'class_id',      c.id,
        'class_name',    c.name,
        'year_level',    c.year_level,
        'teacher_name',  u.name,
        'teacher_email', u.email,
        'school_id',     s.id,
        'school_name',   s.name
      )
      ORDER BY COALESCE(s.name, '~') ASC, u.name ASC, c.name ASC
    ), '[]'::JSON)
    FROM classes c
    JOIN users u ON u.id = c.teacher_id
    LEFT JOIN school_members sm ON sm.user_id = c.teacher_id
    LEFT JOIN schools s ON s.id = sm.school_id
    WHERE (c.archived IS NULL OR c.archived = false)
  );
END;
$$;

-- 3. admin_add_student_to_class — enrols a student in a class (idempotent)
CREATE OR REPLACE FUNCTION admin_add_student_to_class(
  p_student_id UUID,
  p_class_id   UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT;
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  -- Verify the target user is actually a student
  SELECT role INTO v_role FROM users WHERE id = p_student_id;
  IF v_role IS DISTINCT FROM 'student' THEN
    RETURN json_build_object('success', false, 'message', 'User is not a student');
  END IF;

  -- Verify class exists and is not archived
  IF NOT EXISTS (
    SELECT 1 FROM classes WHERE id = p_class_id AND (archived IS NULL OR archived = false)
  ) THEN
    RETURN json_build_object('success', false, 'message', 'Class not found or is archived');
  END IF;

  INSERT INTO class_members (class_id, user_id)
  VALUES (p_class_id, p_student_id)
  ON CONFLICT DO NOTHING;

  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_unassigned_students() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_get_all_classes() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_add_student_to_class(UUID, UUID) TO authenticated;
