-- ============================================================
-- MIGRATION 173: get_other_instrument_custom_names
--
-- Returns (user_id, custom_instrument_name) for every "Other
-- Instrument" student_progress row belonging to a student the
-- calling teacher/admin can see — using the same visibility
-- rules as get_class_students (class owner, co-teacher, or
-- same-school peer; admins see everyone).
--
-- Used by the grading modal's "Which instrument?" picker so
-- teachers can label "Other Instrument" ratings with the
-- student's actual instrument name (e.g. "Violin" vs "Clarinet").
-- A direct SELECT on student_progress only returns rows for
-- classes the caller directly owns (RLS from migration 010), so
-- co-teachers, school peers and admins would otherwise see an
-- incomplete (or empty) list.
-- ============================================================

CREATE OR REPLACE FUNCTION get_other_instrument_custom_names()
RETURNS TABLE (
  user_id UUID,
  custom_instrument_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();

  IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_user_id AND role IN ('teacher', 'admin')) THEN
    RAISE EXCEPTION 'Permission denied: must be a teacher or admin';
  END IF;

  IF is_admin() THEN
    RETURN QUERY
    SELECT DISTINCT sp.user_id, sp.custom_instrument_name
    FROM student_progress sp
    JOIN instruments i ON i.id = sp.instrument_id
    WHERE i.name = 'Other Instrument'
      AND sp.custom_instrument_name IS NOT NULL;
  ELSE
    RETURN QUERY
    SELECT DISTINCT sp.user_id, sp.custom_instrument_name
    FROM student_progress sp
    JOIN instruments i ON i.id = sp.instrument_id
    WHERE i.name = 'Other Instrument'
      AND sp.custom_instrument_name IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM class_members cm
        JOIN classes c ON c.id = cm.class_id
        WHERE cm.user_id = sp.user_id
          AND (
            c.teacher_id = v_user_id
            OR is_class_teacher_or_coteacher(c.id)
            OR teachers_share_school(v_user_id, c.teacher_id)
          )
      );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION get_other_instrument_custom_names() TO authenticated;
