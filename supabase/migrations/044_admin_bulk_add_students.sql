-- Allow admins to bulk add students to any teacher's class
-- Updates RPC functions to authorize admins alongside the owning teacher

-- Helper: check if the current user is an admin
-- (reuse existing is_admin() if available, otherwise create)
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================================
-- 1. Update get_teacher_classes to return all classes for admins (with teacher name)
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
-- 2. Update get_class_students to allow admin access
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_class_students(
  p_class_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_current_user_id UUID;
  v_is_authorized BOOLEAN;
  v_result JSON;
BEGIN
  v_current_user_id := auth.uid();

  -- Check authorization: user must be either:
  -- 1. The teacher of this class, OR
  -- 2. A member of this class, OR
  -- 3. An admin
  SELECT (
    EXISTS (
      SELECT 1
      FROM classes c
      WHERE c.id = p_class_id
        AND c.teacher_id = v_current_user_id
    )
    OR
    EXISTS (
      SELECT 1
      FROM class_members cm
      WHERE cm.class_id = p_class_id
        AND cm.user_id = v_current_user_id
    )
    OR
    is_admin()
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this class';
  END IF;

  -- Get all students in the class with their progress
  SELECT json_agg(
    json_build_object(
      'id', cm.id,
      'class_id', cm.class_id,
      'user_id', cm.user_id,
      'joined_at', cm.joined_at,
      'users', json_build_object(
        'id', u.id,
        'name', u.name,
        'email', u.email
      ),
      'student_progress', (
        SELECT json_agg(
          json_build_object(
            'instrument_id', sp.instrument_id,
            'current_level', sp.current_level,
            'current_branch', sp.current_branch
          )
        )
        FROM student_progress sp
        WHERE sp.user_id = u.id
      )
    )
    ORDER BY u.name
  )
  INTO v_result
  FROM class_members cm
  JOIN users u ON u.id = cm.user_id
  WHERE cm.class_id = p_class_id;

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
-- 3. Update add_pending_enrollments to allow admin access
-- ============================================================================
CREATE OR REPLACE FUNCTION add_pending_enrollments(
  p_class_id UUID,
  p_emails TEXT[]
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_id UUID;
  v_user_id UUID;
  v_email TEXT;
  v_added_count INTEGER := 0;
  v_skipped_count INTEGER := 0;
  v_already_enrolled_count INTEGER := 0;
BEGIN
  v_user_id := auth.uid();

  -- Verify the class exists
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE id = p_class_id;

  IF v_teacher_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Class not found'
    );
  END IF;

  -- Authorization: must be the class teacher OR an admin
  IF v_teacher_id != v_user_id AND NOT is_admin() THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You do not have permission to add students to this class'
    );
  END IF;

  -- Process each email
  FOREACH v_email IN ARRAY p_emails
  LOOP
    v_email := LOWER(TRIM(v_email));

    IF v_email = '' OR v_email IS NULL THEN
      CONTINUE;
    END IF;

    -- Check if user already exists and is enrolled
    IF EXISTS (
      SELECT 1 FROM class_members cm
      JOIN users u ON u.id = cm.user_id
      WHERE cm.class_id = p_class_id
      AND LOWER(u.email) = v_email
    ) THEN
      v_already_enrolled_count := v_already_enrolled_count + 1;
      CONTINUE;
    END IF;

    -- Check if already in pending enrollments
    IF EXISTS (
      SELECT 1 FROM pending_enrollments
      WHERE class_id = p_class_id
      AND LOWER(email) = v_email
    ) THEN
      v_skipped_count := v_skipped_count + 1;
      CONTINUE;
    END IF;

    -- Add to pending enrollments
    INSERT INTO pending_enrollments (class_id, email, added_by)
    VALUES (p_class_id, v_email, v_user_id);

    v_added_count := v_added_count + 1;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'added', v_added_count,
    'skipped', v_skipped_count,
    'already_enrolled', v_already_enrolled_count,
    'message', format('Added %s email(s). %s already pending. %s already enrolled.',
      v_added_count, v_skipped_count, v_already_enrolled_count)
  );
END;
$$;

-- ============================================================================
-- 4. Update get_pending_enrollments to allow admin access
-- ============================================================================
CREATE OR REPLACE FUNCTION get_pending_enrollments(p_class_id UUID)
RETURNS TABLE (
  id UUID,
  email TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_id UUID;
BEGIN
  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE classes.id = p_class_id;

  -- Allow the class teacher OR an admin
  IF v_teacher_id IS NULL OR (v_teacher_id != auth.uid() AND NOT is_admin()) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT pe.id, pe.email, pe.created_at
  FROM pending_enrollments pe
  WHERE pe.class_id = p_class_id
  ORDER BY pe.created_at DESC;
END;
$$;

-- ============================================================================
-- 5. Update remove_pending_enrollment to allow admin access
-- ============================================================================
CREATE OR REPLACE FUNCTION remove_pending_enrollment(p_enrollment_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_class_id UUID;
  v_teacher_id UUID;
BEGIN
  SELECT class_id INTO v_class_id
  FROM pending_enrollments
  WHERE id = p_enrollment_id;

  IF v_class_id IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Pending enrollment not found'
    );
  END IF;

  SELECT teacher_id INTO v_teacher_id
  FROM classes
  WHERE id = v_class_id;

  -- Allow the class teacher OR an admin
  IF v_teacher_id != auth.uid() AND NOT is_admin() THEN
    RETURN json_build_object(
      'success', false,
      'message', 'You do not have permission to remove this enrollment'
    );
  END IF;

  DELETE FROM pending_enrollments WHERE id = p_enrollment_id;

  RETURN json_build_object(
    'success', true,
    'message', 'Pending enrollment removed'
  );
END;
$$;

-- ============================================================================
-- 6. Add admin RLS policies on pending_enrollments
-- ============================================================================
CREATE POLICY "Admins can view all pending enrollments"
  ON pending_enrollments FOR SELECT
  USING (is_admin());

CREATE POLICY "Admins can add pending enrollments to any class"
  ON pending_enrollments FOR INSERT
  WITH CHECK (is_admin() AND added_by = auth.uid());

CREATE POLICY "Admins can delete any pending enrollment"
  ON pending_enrollments FOR DELETE
  USING (is_admin());

-- ============================================================================
-- 7. Add admin RLS policies on class_members (for roster management)
-- ============================================================================
CREATE POLICY "Admins can view all class members"
  ON class_members FOR SELECT
  USING (is_admin());

CREATE POLICY "Admins can manage all class members"
  ON class_members FOR ALL
  USING (is_admin());
