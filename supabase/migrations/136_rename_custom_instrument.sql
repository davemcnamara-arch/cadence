-- Allows a student (or teacher on behalf of a student) to rename the
-- custom_instrument_name on a student_progress row. Follows the same
-- access-control pattern as add/remove_instrument_for_student.

CREATE OR REPLACE FUNCTION rename_custom_instrument(
  p_student_id  UUID,
  p_progress_id UUID,
  p_new_name    TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_caller_id  UUID;
  v_has_access BOOLEAN;
BEGIN
  v_caller_id := auth.uid();

  IF p_new_name IS NULL OR trim(p_new_name) = '' THEN
    RAISE EXCEPTION 'Instrument name cannot be empty';
  END IF;

  SELECT (
    v_caller_id = p_student_id
    OR EXISTS (
      SELECT 1
      FROM classes c
      JOIN class_members cm ON c.id = cm.class_id
      WHERE c.teacher_id = v_caller_id
        AND cm.user_id = p_student_id
    )
  ) INTO v_has_access;

  IF NOT v_has_access THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student';
  END IF;

  UPDATE student_progress
  SET custom_instrument_name = trim(p_new_name),
      last_updated = NOW()
  WHERE id = p_progress_id
    AND user_id = p_student_id
    AND custom_instrument_name IS NOT NULL;  -- only "Other" rows have a custom name

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Progress record not found or is not a custom instrument';
  END IF;

  RETURN json_build_object('success', true, 'new_name', trim(p_new_name));
END;
$$;

GRANT EXECUTE ON FUNCTION rename_custom_instrument(UUID, UUID, TEXT) TO authenticated;
