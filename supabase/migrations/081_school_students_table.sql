-- ============================================================
-- MIGRATION 081: Explicit school_students table
-- Students can now be directly assigned to a school by admin,
-- or auto-assigned when they join a class whose teacher is a
-- school member.
-- ============================================================

-- ============================================================
-- TABLE: school_students
-- ============================================================
CREATE TABLE IF NOT EXISTS school_students (
  school_id  UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (school_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_school_students_school_id ON school_students(school_id);
CREATE INDEX IF NOT EXISTS idx_school_students_user_id   ON school_students(user_id);

-- ============================================================
-- Backfill: add existing students who are in classes taught by
-- current school members.
-- ============================================================
INSERT INTO school_students (school_id, user_id)
SELECT DISTINCT sm.school_id, cm.user_id
FROM school_members sm
JOIN classes c       ON c.teacher_id = sm.user_id AND c.archived = false
JOIN class_members cm ON cm.class_id = c.id
WHERE NOT EXISTS (
  SELECT 1 FROM school_students ss
  WHERE ss.school_id = sm.school_id AND ss.user_id = cm.user_id
);

-- ============================================================
-- FUNCTION: get_school_students (updated)
-- Now queries school_students directly instead of via class chain
-- ============================================================
CREATE OR REPLACE FUNCTION get_school_students(p_school_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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
    'students', (
      SELECT json_agg(
        json_build_object(
          'user_id', u.id,
          'name', u.name,
          'email', u.email,
          'class_name', (
            SELECT c.name FROM classes c
            JOIN class_members cm ON cm.class_id = c.id
            WHERE cm.user_id = u.id AND c.archived = false
            ORDER BY c.created_at DESC LIMIT 1
          ),
          'teacher_name', (
            SELECT t.name FROM classes c
            JOIN class_members cm ON cm.class_id = c.id
            JOIN users t ON t.id = c.teacher_id
            WHERE cm.user_id = u.id AND c.archived = false
            ORDER BY c.created_at DESC LIMIT 1
          ),
          'instruments', (
            SELECT json_agg(
              json_build_object(
                'instrument_name', i.name,
                'instrument_icon', i.icon,
                'current_level', sp.current_level
              )
              ORDER BY i.display_order
            )
            FROM student_progress sp
            JOIN instruments i ON i.id = sp.instrument_id
            WHERE sp.user_id = u.id
          ),
          'songs_learning', (
            SELECT COUNT(*) FROM student_songs ss
            WHERE ss.user_id = u.id AND ss.status = 'learning'
          ),
          'songs_mastered', (
            SELECT COUNT(*) FROM student_songs ss
            WHERE ss.user_id = u.id AND ss.status = 'mastered'
          )
        )
        ORDER BY u.name ASC
      )
      FROM school_students sch_s
      JOIN users u ON u.id = sch_s.user_id
      WHERE sch_s.school_id = p_school_id
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: get_school_dashboard (updated stats)
-- Use school_students for student_count
-- ============================================================
CREATE OR REPLACE FUNCTION get_school_dashboard(p_school_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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
            SELECT COUNT(*) FROM classes c
            WHERE c.teacher_id = u.id AND c.archived = false
          ),
          'student_count', (
            SELECT COUNT(DISTINCT cm.user_id)
            FROM classes c
            JOIN class_members cm ON cm.class_id = c.id
            WHERE c.teacher_id = u.id AND c.archived = false
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
          SELECT COUNT(*) FROM classes c
          JOIN school_members sm ON sm.user_id = c.teacher_id AND sm.school_id = p_school_id
          WHERE c.archived = false
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
-- FUNCTION: get_all_schools (updated student_count)
-- ============================================================
CREATE OR REPLACE FUNCTION get_all_schools()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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
            SELECT COUNT(*) FROM classes c
            JOIN school_members sm ON sm.user_id = c.teacher_id AND sm.school_id = s.id
            WHERE c.archived = false
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
-- FUNCTION: get_assignable_students
-- Returns students not yet assigned to this school
-- ============================================================
CREATE OR REPLACE FUNCTION get_assignable_students(p_school_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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
    'students', (
      SELECT json_agg(
        json_build_object(
          'user_id', u.id,
          'name', u.name,
          'email', u.email,
          'class_name', (
            SELECT c.name FROM classes c
            JOIN class_members cm ON cm.class_id = c.id
            WHERE cm.user_id = u.id AND c.archived = false
            ORDER BY c.created_at DESC LIMIT 1
          )
        )
        ORDER BY u.name ASC
      )
      FROM users u
      WHERE u.role = 'student'
        AND u.id NOT IN (
          SELECT ss.user_id FROM school_students ss WHERE ss.school_id = p_school_id
        )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: bulk_assign_students_to_school
-- Admin assigns multiple students to a school directly
-- ============================================================
CREATE OR REPLACE FUNCTION bulk_assign_students_to_school(p_school_id UUID, p_user_ids UUID[])
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role TEXT;
  v_uid UUID;
  v_added INT := 0;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM schools WHERE id = p_school_id) THEN
    RETURN json_build_object('success', false, 'message', 'School not found');
  END IF;

  FOREACH v_uid IN ARRAY p_user_ids
  LOOP
    INSERT INTO school_students (school_id, user_id)
    SELECT p_school_id, v_uid
    WHERE EXISTS (SELECT 1 FROM users WHERE id = v_uid AND role = 'student')
      AND NOT EXISTS (SELECT 1 FROM school_students WHERE school_id = p_school_id AND user_id = v_uid)
    ON CONFLICT (school_id, user_id) DO NOTHING;

    IF FOUND THEN
      v_added := v_added + 1;
    END IF;
  END LOOP;

  RETURN json_build_object(
    'success', true,
    'added', v_added,
    'message', v_added || ' student' || CASE WHEN v_added != 1 THEN 's' ELSE '' END || ' assigned to school'
  );
END;
$$;

-- ============================================================
-- TRIGGER: auto-assign student to school on class_members INSERT
-- When a student joins a class, if that class's teacher is a
-- school member, auto-add the student to that school.
-- ============================================================
CREATE OR REPLACE FUNCTION auto_assign_student_to_school()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_teacher_id UUID;
  v_school_id UUID;
BEGIN
  -- Get the teacher for this class
  SELECT teacher_id INTO v_teacher_id FROM classes WHERE id = NEW.class_id;

  -- Find a school this teacher belongs to
  SELECT school_id INTO v_school_id
  FROM school_members
  WHERE user_id = v_teacher_id
  LIMIT 1;

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
