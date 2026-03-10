-- ============================================================
-- MIGRATION 092: Allow teachers to create classes for peer
--                teachers at the same school
--
-- Changes:
--   1. Add helper function teachers_share_school() to check
--      whether two teachers share at least one school
--   2. Relax the "Teachers can create classes" INSERT policy so
--      a teacher can insert a class whose teacher_id belongs to
--      a colleague at the same school (no hierarchy required —
--      any teacher at a shared school can do this)
--   3. Add get_school_peer_teachers() RPC so the UI can list
--      colleagues the current teacher can create classes for
-- ============================================================

-- ============================================================
-- 1. Helper: do two users share at least one school?
-- ============================================================
CREATE OR REPLACE FUNCTION teachers_share_school(
  p_teacher_a UUID,
  p_teacher_b UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM school_members sm1
    JOIN school_members sm2 ON sm1.school_id = sm2.school_id
    WHERE sm1.user_id = p_teacher_a
      AND sm2.user_id = p_teacher_b
  )
$$;

GRANT EXECUTE ON FUNCTION teachers_share_school(UUID, UUID) TO authenticated;

-- ============================================================
-- 2. Update INSERT policy on classes
--    Old: teacher_id = auth.uid()  (own classes only)
--    New: also allow when the target teacher shares a school
-- ============================================================
DROP POLICY IF EXISTS "Teachers can create classes" ON classes;

CREATE POLICY "Teachers can create classes" ON classes
FOR INSERT WITH CHECK (
  -- Creating a class for yourself
  teacher_id = auth.uid()
  OR
  -- Creating a class for a peer teacher at the same school
  -- (caller must be a teacher/admin and share a school with the target teacher)
  (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid() AND role IN ('teacher', 'admin')
    )
    AND teachers_share_school(auth.uid(), teacher_id)
  )
);

-- ============================================================
-- 3. RPC: get_school_peer_teachers
--    Returns teacher/admin users who share a school with the
--    caller (optionally filtered to a specific school).
--    The caller themselves is excluded from the result.
-- ============================================================
CREATE OR REPLACE FUNCTION get_school_peer_teachers(
  p_school_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id    UUID,
  name  TEXT,
  email TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_school_id UUID;
BEGIN
  -- Resolve which school to scope the query to
  IF p_school_id IS NOT NULL THEN
    -- Use the supplied school — but only if caller is a member of it
    SELECT sm.school_id INTO v_school_id
    FROM school_members sm
    WHERE sm.user_id = auth.uid() AND sm.school_id = p_school_id
    LIMIT 1;
  ELSE
    -- Default to the caller's earliest-joined school
    SELECT sm.school_id INTO v_school_id
    FROM school_members sm
    WHERE sm.user_id = auth.uid()
    ORDER BY sm.joined_at ASC
    LIMIT 1;
  END IF;

  IF v_school_id IS NULL THEN
    RETURN; -- Caller has no school membership; return empty
  END IF;

  RETURN QUERY
  SELECT u.id, u.name, u.email
  FROM users u
  JOIN school_members sm ON u.id = sm.user_id
  WHERE sm.school_id = v_school_id
    AND u.id != auth.uid()
    AND u.role IN ('teacher', 'admin')
  ORDER BY u.name;
END;
$$;

GRANT EXECUTE ON FUNCTION get_school_peer_teachers(UUID) TO authenticated;
