-- Fix ambiguous "id" column reference in get_pending_enrollments.
-- RETURNS TABLE declares `id` as a PL/pgSQL output variable, which
-- conflicts with `classes.id` in the WHERE clause of the initial SELECT.
-- Qualifying with the table name resolves the 42702 error.

CREATE OR REPLACE FUNCTION get_pending_enrollments(p_class_id UUID)
RETURNS TABLE (
  id         UUID,
  email      TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_class_teacher UUID;
BEGIN
  SELECT teacher_id INTO v_class_teacher
  FROM classes
  WHERE classes.id = p_class_id;

  IF NOT is_admin()
     AND NOT is_class_teacher_or_coteacher(p_class_id)
     AND NOT (
       v_class_teacher IS NOT NULL
       AND teachers_share_school(auth.uid(), v_class_teacher)
     )
  THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT pe.id, pe.email, pe.created_at
  FROM pending_enrollments pe
  WHERE pe.class_id = p_class_id
  ORDER BY pe.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION get_pending_enrollments(UUID) TO authenticated;
