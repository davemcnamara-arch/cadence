-- ============================================================
-- MIGRATION 084: Scope classes to their school of origin
--
-- Problem: classes had no school_id, so they were linked to
-- schools only via school_members.user_id = classes.teacher_id.
-- A teacher assigned to N schools would have ALL their classes
-- appear in every school's dashboard.
--
-- Fix:
--   1. Add school_id to classes (nullable FK)
--   2. Backfill from each teacher's earliest-joined school
--   3. BEFORE INSERT trigger sets school_id at creation time
--   4. AFTER INSERT trigger (auto-assign) also sets school_id
--   5. get_school_dashboard: filter class counts by school_id
--   6. get_all_schools: same fix, plus use school_students for
--      student_count to match the 081 migration approach
-- ============================================================

-- ============================================================
-- 1. Add school_id column to classes
-- ============================================================
ALTER TABLE classes
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES schools(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_classes_school_id ON classes(school_id);

-- ============================================================
-- 2. Backfill: each class gets its teacher's earliest school
-- ============================================================
UPDATE classes c
SET school_id = (
  SELECT sm.school_id
  FROM school_members sm
  WHERE sm.user_id = c.teacher_id
  ORDER BY sm.joined_at ASC
  LIMIT 1
)
WHERE c.school_id IS NULL;

-- ============================================================
-- 3. BEFORE INSERT trigger: auto-set school_id from teacher's
--    current (earliest-joined) school at class creation time
-- ============================================================
CREATE OR REPLACE FUNCTION set_class_school_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_school_id UUID;
BEGIN
  -- Only set if not already provided
  IF NEW.school_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  -- Find the teacher's earliest-joined school
  SELECT sm.school_id INTO v_school_id
  FROM school_members sm
  WHERE sm.user_id = NEW.teacher_id
  ORDER BY sm.joined_at ASC
  LIMIT 1;

  IF v_school_id IS NOT NULL THEN
    NEW.school_id := v_school_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_class_school_id ON classes;
CREATE TRIGGER trg_set_class_school_id
  BEFORE INSERT ON classes
  FOR EACH ROW
  EXECUTE FUNCTION set_class_school_id();

-- ============================================================
-- 4. Update AFTER INSERT trigger (auto_assign_teacher_to_school)
--    to also set school_id on the new class when a teacher is
--    auto-assigned to their first school.
-- ============================================================
CREATE OR REPLACE FUNCTION auto_assign_teacher_to_school()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_teacher_role TEXT;
  v_school_id UUID;
BEGIN
  -- Only act on teacher/admin users
  SELECT role INTO v_teacher_role FROM users WHERE id = NEW.teacher_id;
  IF v_teacher_role NOT IN ('teacher', 'admin') THEN
    RETURN NEW;
  END IF;

  -- Skip if teacher is already in a school (BEFORE trigger handles school_id)
  IF EXISTS (SELECT 1 FROM school_members WHERE user_id = NEW.teacher_id) THEN
    RETURN NEW;
  END IF;

  -- Find the first school in the system
  SELECT id INTO v_school_id FROM schools ORDER BY created_at ASC LIMIT 1;
  IF v_school_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Add teacher to school
  INSERT INTO school_members (school_id, user_id, school_role)
  VALUES (v_school_id, NEW.teacher_id, v_teacher_role)
  ON CONFLICT (school_id, user_id) DO NOTHING;

  -- Back-set school_id on the class that was just created
  -- (BEFORE trigger ran when teacher had no school yet, so school_id was NULL)
  IF NEW.school_id IS NULL THEN
    UPDATE classes SET school_id = v_school_id WHERE id = NEW.id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_assign_teacher_to_school ON classes;
CREATE TRIGGER trg_auto_assign_teacher_to_school
  AFTER INSERT ON classes
  FOR EACH ROW
  EXECUTE FUNCTION auto_assign_teacher_to_school();

-- ============================================================
-- 5. FUNCTION: get_school_dashboard (updated)
--    Filter class_count / student_count per teacher by school_id
--    instead of relying on the school_members join
-- ============================================================
CREATE OR REPLACE FUNCTION get_school_dashboard(p_school_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_result JSON;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role NOT IN ('teacher', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Access denied');
  END IF;

  SELECT json_build_object(
    'success', true,
    'teachers', (
      SELECT json_agg(
        json_build_object(
          'user_id', u.id,
          'name', u.name,
          'email', u.email,
          'school_role', sm.school_role,
          'class_count', (
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

-- ============================================================
-- 6. FUNCTION: get_all_schools (updated)
--    Use school_id for class_count, school_students for student_count
-- ============================================================
CREATE OR REPLACE FUNCTION get_all_schools()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_result JSON;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  SELECT json_build_object(
    'success', true,
    'schools', (
      SELECT json_agg(
        json_build_object(
          'id', s.id,
          'name', s.name,
          'join_code', s.join_code,
          'created_at', s.created_at,
          'teacher_count', (
            SELECT COUNT(*) FROM school_members sm WHERE sm.school_id = s.id
          ),
          'class_count', (
            SELECT COUNT(*)
            FROM classes c
            WHERE c.school_id = s.id
              AND c.archived = false
          ),
          'student_count', (
            SELECT COUNT(*) FROM school_students ss WHERE ss.school_id = s.id
          )
        )
        ORDER BY s.created_at ASC
      )
      FROM schools s
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- 7. FUNCTION: auto_assign_student_to_school (updated)
--    Use the class's own school_id instead of looking up the
--    teacher's school_members row (which is non-deterministic
--    when a teacher belongs to multiple schools).
-- ============================================================
CREATE OR REPLACE FUNCTION auto_assign_student_to_school()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_school_id UUID;
BEGIN
  -- Use the class's school_id, set at class creation time
  SELECT school_id INTO v_school_id FROM classes WHERE id = NEW.class_id;

  IF v_school_id IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO school_students (school_id, user_id)
  VALUES (v_school_id, NEW.user_id)
  ON CONFLICT (school_id, user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_assign_student_to_school ON class_members;
CREATE TRIGGER trg_auto_assign_student_to_school
  AFTER INSERT ON class_members
  FOR EACH ROW
  EXECUTE FUNCTION auto_assign_student_to_school();

GRANT EXECUTE ON FUNCTION set_class_school_id() TO authenticated;
GRANT EXECUTE ON FUNCTION auto_assign_teacher_to_school() TO authenticated;
GRANT EXECUTE ON FUNCTION auto_assign_student_to_school() TO authenticated;
GRANT EXECUTE ON FUNCTION get_school_dashboard(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_schools() TO authenticated;
