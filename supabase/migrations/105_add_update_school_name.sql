-- ============================================================
-- MIGRATION 105: Add update_school_name() RPC
--
-- Allows a school admin (or the creator) to rename their school.
-- Used during school plan onboarding when the webhook creates the
-- school with the default name "My School".
-- ============================================================

CREATE OR REPLACE FUNCTION update_school_name(p_school_id UUID, p_name TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_authorized BOOLEAN;
BEGIN
  IF p_name IS NULL OR TRIM(p_name) = '' THEN
    RETURN json_build_object('success', false, 'message', 'School name cannot be empty');
  END IF;

  -- Authorized if caller is a school admin member OR the original creator
  SELECT EXISTS (
    SELECT 1 FROM school_members
    WHERE school_id = p_school_id
      AND user_id   = v_uid
      AND school_role = 'admin'
  ) OR EXISTS (
    SELECT 1 FROM schools
    WHERE id         = p_school_id
      AND created_by = v_uid
  ) INTO v_authorized;

  IF NOT v_authorized THEN
    RETURN json_build_object('success', false, 'message', 'Only school admins can rename the school');
  END IF;

  UPDATE schools SET name = TRIM(p_name) WHERE id = p_school_id;

  RETURN json_build_object('success', true, 'message', 'School renamed successfully');
END;
$$;

GRANT EXECUTE ON FUNCTION update_school_name(UUID, TEXT) TO authenticated;
