-- ============================================================
-- MIGRATION 095: Shared class visibility setting for schools
--
-- When enabled for a school, all teachers at that school can
-- view and edit all classes in the school — in line with the
-- no-hierarchy policy introduced in migration 092.
--
-- Changes:
--   1. Add shared_class_visibility column to schools
--   2. Helper: school_has_shared_visibility(p_school_id)
--   3. RLS UPDATE policy for peer teachers in shared schools
--   4. Updated get_my_schools() to include the new flag
--   5. Updated get_teacher_classes() to surface all school
--      classes when shared visibility is on (with teacher_name)
--   6. RPC: set_school_shared_visibility (school admin or admin)
--   7. Updated get_school_dashboard() to expose the flag
-- ============================================================

-- ============================================================
-- 1. Add shared_class_visibility to schools
-- ============================================================
ALTER TABLE schools
  ADD COLUMN IF NOT EXISTS shared_class_visibility BOOLEAN NOT NULL DEFAULT FALSE;

-- ============================================================
-- 2. Helper: does a school have shared class visibility on?
-- ============================================================
CREATE OR REPLACE FUNCTION school_has_shared_visibility(p_school_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT shared_class_visibility FROM schools WHERE id = p_school_id),
    false
  )
$$;

GRANT EXECUTE ON FUNCTION school_has_shared_visibility(UUID) TO authenticated;

-- ============================================================
-- 3. RLS UPDATE policy: peer teachers in shared schools
--    can update any class in their school
-- ============================================================
DROP POLICY IF EXISTS "Peer teachers can update classes in shared schools" ON classes;

CREATE POLICY "Peer teachers can update classes in shared schools" ON classes
FOR UPDATE USING (
  school_id IS NOT NULL
  AND school_has_shared_visibility(school_id)
  AND EXISTS (
    SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin')
  )
  AND teachers_share_school(auth.uid(), teacher_id)
);

-- ============================================================
-- 4. Updated get_my_schools(): include shared_class_visibility
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_schools()
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

  SELECT COALESCE(
    json_agg(
      json_build_object(
        'id',                      s.id,
        'name',                    s.name,
        'join_code',               s.join_code,
        'school_role',             sm.school_role,
        'joined_at',               sm.joined_at,
        'shared_class_visibility', s.shared_class_visibility
      )
      ORDER BY sm.joined_at ASC
    ),
    '[]'::json
  ) INTO v_result
  FROM school_members sm
  JOIN schools s ON s.id = sm.school_id
  WHERE sm.user_id = v_user_id;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_my_schools() TO authenticated;

-- ============================================================
-- 5. Updated get_teacher_classes():
--    - Always returns teacher_name for every class
--    - When shared_class_visibility is on for the school,
--      returns all classes in the school (not just own)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_teacher_classes(
  p_teacher_id       UUID,
  p_include_archived BOOLEAN DEFAULT false,
  p_school_id        UUID    DEFAULT NULL
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
  v_shared_visibility   BOOLEAN := FALSE;
  v_effective_school_id UUID;
BEGIN
  v_current_user_id := auth.uid();
  v_is_admin := is_admin();

  -- Authorization: must be requesting own classes OR be an admin
  IF v_current_user_id != p_teacher_id AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Permission denied: You can only view your own classes';
  END IF;

  -- For non-admins, check if shared visibility is enabled for the school
  IF NOT v_is_admin THEN
    -- Determine effective school (explicit param takes priority)
    IF p_school_id IS NOT NULL THEN
      v_effective_school_id := p_school_id;
    ELSE
      SELECT sm.school_id INTO v_effective_school_id
      FROM school_members sm
      WHERE sm.user_id = p_teacher_id
      ORDER BY sm.joined_at ASC
      LIMIT 1;
    END IF;

    IF v_effective_school_id IS NOT NULL THEN
      SELECT s.shared_class_visibility INTO v_shared_visibility
      FROM schools s
      WHERE s.id = v_effective_school_id;
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

  ELSIF v_shared_visibility AND v_effective_school_id IS NOT NULL THEN
    -- Shared visibility: return all classes in the school, ordered by teacher then name
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
      ORDER BY u.name, c.name
    )
    INTO v_result
    FROM classes c
    JOIN  users u ON u.id = c.teacher_id
    LEFT JOIN schools s ON s.id = c.school_id
    WHERE c.school_id = v_effective_school_id
      AND (p_include_archived = true OR c.archived = false);

  ELSE
    -- Standard: return only the teacher's own classes
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
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    RETURN '[]'::json;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_teacher_classes(UUID, BOOLEAN, UUID) TO authenticated;

-- ============================================================
-- 6. RPC: set_school_shared_visibility
--    Callable by school admins (school_role = 'admin') and
--    system admins (role = 'admin').
-- ============================================================
CREATE OR REPLACE FUNCTION set_school_shared_visibility(
  p_school_id UUID,
  p_enabled   BOOLEAN
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id   UUID := auth.uid();
  v_caller_role TEXT;
  v_school_role TEXT;
BEGIN
  SELECT role INTO v_caller_role FROM users WHERE id = v_caller_id;

  -- System admin can update any school
  IF v_caller_role != 'admin' THEN
    -- Must be a school admin of this specific school
    SELECT school_role INTO v_school_role
    FROM school_members
    WHERE school_id = p_school_id AND user_id = v_caller_id;

    IF v_school_role IS NULL OR v_school_role != 'admin' THEN
      RETURN json_build_object(
        'success', false,
        'message', 'Only school admins can change this setting'
      );
    END IF;
  END IF;

  UPDATE schools
  SET shared_class_visibility = p_enabled
  WHERE id = p_school_id;

  RETURN json_build_object(
    'success', true,
    'message', CASE WHEN p_enabled
      THEN 'Shared class visibility enabled — all teachers can now see and edit all classes'
      ELSE 'Shared class visibility disabled — teachers see only their own classes'
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION set_school_shared_visibility(UUID, BOOLEAN) TO authenticated;

-- ============================================================
-- 7. Updated get_school_dashboard(): expose shared_class_visibility
-- ============================================================
CREATE OR REPLACE FUNCTION get_school_dashboard(p_school_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID;
  v_user_role TEXT;
  v_result    JSON;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role NOT IN ('teacher', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Access denied');
  END IF;

  SELECT json_build_object(
    'success', true,
    'shared_class_visibility', (
      SELECT shared_class_visibility FROM schools WHERE id = p_school_id
    ),
    'teachers', (
      SELECT json_agg(
        json_build_object(
          'user_id',      u.id,
          'name',         u.name,
          'email',        u.email,
          'school_role',  sm.school_role,
          'class_count',  (
            SELECT COUNT(*)
            FROM classes c
            WHERE c.teacher_id = u.id
              AND c.school_id = p_school_id
              AND c.archived = false
          ),
          'student_count', (
            SELECT COUNT(DISTINCT cm.user_id)
            FROM classes c
            JOIN class_members cm ON cm.class_id = c.id
            WHERE c.teacher_id = u.id
              AND c.school_id = p_school_id
              AND c.archived = false
          )
        )
        ORDER BY sm.school_role DESC, u.name ASC
      )
      FROM school_members sm
      JOIN users u ON u.id = sm.user_id
      WHERE sm.school_id = p_school_id
    ),
    'stats', (
      SELECT json_build_object(
        'teacher_count', (
          SELECT COUNT(*) FROM school_members WHERE school_id = p_school_id
        ),
        'class_count', (
          SELECT COUNT(*)
          FROM classes c
          WHERE c.school_id = p_school_id
            AND c.archived = false
        ),
        'student_count', (
          SELECT COUNT(*) FROM school_students WHERE school_id = p_school_id
        ),
        'instrument_counts', (
          SELECT json_agg(
            json_build_object('name', i.name, 'icon', i.icon, 'count', sp_counts.cnt)
            ORDER BY sp_counts.cnt DESC
          )
          FROM (
            SELECT sp.instrument_id, COUNT(DISTINCT sp.user_id) AS cnt
            FROM student_progress sp
            WHERE sp.user_id IN (
              SELECT user_id FROM school_students WHERE school_id = p_school_id
            )
            GROUP BY sp.instrument_id
          ) sp_counts
          JOIN instruments i ON i.id = sp_counts.instrument_id
        )
      )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_school_dashboard(UUID) TO authenticated;
