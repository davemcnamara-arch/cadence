-- ============================================================
-- MIGRATION 078: get_admin_contact
-- Returns the first admin's name and email so teachers can
-- contact them when no school has been set up yet.
-- ============================================================

CREATE OR REPLACE FUNCTION get_admin_contact()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result JSON;
BEGIN
  SELECT json_build_object(
    'name', u.name,
    'email', u.email
  ) INTO v_result
  FROM users u
  WHERE u.role = 'admin'
  ORDER BY u.created_at ASC
  LIMIT 1;

  RETURN v_result;
END;
$$;
