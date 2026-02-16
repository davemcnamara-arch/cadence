-- Allow admins to see ratings from students who aren't linked to any class.
-- Previously get_all_teacher_students() only returned students in the caller's
-- classes. For admins it now also includes students with no class membership,
-- so their ratings surface in the flagged-ratings / review queue.

-- ============================================================================
-- 1. Update get_all_teacher_students to include unlinked students for admins
-- ============================================================================
CREATE OR REPLACE FUNCTION get_all_teacher_students()
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF is_admin() THEN
    -- Admins get ALL students from every class …
    RETURN QUERY
    SELECT DISTINCT
      u.id AS user_id,
      u.name,
      u.email
    FROM users u
    INNER JOIN class_members cm ON u.id = cm.user_id;

    -- … plus students who are NOT in any class
    RETURN QUERY
    SELECT
      u.id AS user_id,
      u.name,
      u.email
    FROM users u
    WHERE u.role = 'student'
      AND NOT EXISTS (
        SELECT 1 FROM class_members cm WHERE cm.user_id = u.id
      );
  ELSE
    -- Teachers: only students from their own classes (original behaviour)
    RETURN QUERY
    SELECT DISTINCT
      u.id AS user_id,
      u.name,
      u.email
    FROM users u
    INNER JOIN class_members cm ON u.id = cm.user_id
    INNER JOIN classes c ON cm.class_id = c.id
    WHERE c.teacher_id = auth.uid();
  END IF;
END;
$$;

-- ============================================================================
-- 2. Update search_teacher_students to include unlinked students for admins
-- ============================================================================
CREATE OR REPLACE FUNCTION search_teacher_students()
RETURNS TABLE (
  user_id UUID,
  name TEXT,
  email TEXT,
  class_id UUID,
  class_name TEXT,
  joined_at TIMESTAMPTZ,
  is_pending BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF is_admin() THEN
    -- Active students in any class
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
    WHERE c.archived IS NOT TRUE;

    -- Students not linked to any class
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

    -- Pending enrollments for any class
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
    WHERE c.archived IS NOT TRUE;
  ELSE
    -- Active students in teacher's classes
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
      AND c.archived IS NOT TRUE;

    -- Pending enrollments for teacher's classes
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
      AND c.archived IS NOT TRUE;
  END IF;
END;
$$;
