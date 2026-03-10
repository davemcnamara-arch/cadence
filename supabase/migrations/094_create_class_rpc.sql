-- ============================================================
-- MIGRATION 094: create_class RPC for safe peer class creation
--
-- Problem: Direct INSERT into classes by a teacher creating a
-- class for a peer fails with RLS 403, even with the relaxed
-- policy from migration 093, because the Supabase JS client
-- hits RLS before triggers run.
--
-- Fix: Replace the direct INSERT with a SECURITY DEFINER RPC
-- that performs the same auth checks server-side and is immune
-- to RLS.  The existing triggers (set_class_school_id,
-- auto_assign_teacher_to_school) still fire normally.
-- ============================================================

CREATE OR REPLACE FUNCTION create_class(
  p_name                  TEXT,
  p_year_level            TEXT    DEFAULT NULL,
  p_teacher_id            UUID    DEFAULT NULL,  -- NULL = assign to caller
  p_school_id             UUID    DEFAULT NULL,
  p_pending_teacher_email TEXT    DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id   UUID := auth.uid();
  v_caller_role TEXT;
  v_assigned_to UUID;
  v_code        TEXT;
  v_attempt     INT  := 0;
  v_class_id    UUID;
BEGIN
  -- ── Authorization ────────────────────────────────────────
  SELECT role INTO v_caller_role
  FROM users
  WHERE id = v_caller_id;

  IF v_caller_role NOT IN ('teacher', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
  END IF;

  -- ── Determine class owner ────────────────────────────────
  -- Pending-teacher flow: caller holds the class until the
  -- invited teacher accepts, so owner stays as caller.
  IF p_pending_teacher_email IS NOT NULL THEN
    v_assigned_to := v_caller_id;

  ELSIF p_teacher_id IS NULL OR p_teacher_id = v_caller_id THEN
    v_assigned_to := v_caller_id;

  ELSE
    -- Creating for a peer — verify they share a school
    v_assigned_to := p_teacher_id;
    IF NOT is_admin() AND NOT teachers_share_school(v_caller_id, v_assigned_to) THEN
      RETURN json_build_object(
        'success', false,
        'message',  'You can only create classes for teachers at your school'
      );
    END IF;
  END IF;

  -- ── Generate a unique class code ─────────────────────────
  LOOP
    v_code := generate_class_code();
    EXIT WHEN NOT EXISTS (SELECT 1 FROM classes WHERE class_code = v_code);
    v_attempt := v_attempt + 1;
    IF v_attempt >= 20 THEN
      RETURN json_build_object('success', false, 'message', 'Could not generate a unique class code');
    END IF;
  END LOOP;

  -- ── Insert (triggers still fire) ─────────────────────────
  INSERT INTO classes (
    class_code,
    name,
    teacher_id,
    year_level,
    pending_teacher_email,
    school_id
  ) VALUES (
    v_code,
    p_name,
    v_assigned_to,
    NULLIF(TRIM(p_year_level), ''),
    p_pending_teacher_email,
    p_school_id
  )
  RETURNING id INTO v_class_id;

  RETURN json_build_object(
    'success',    true,
    'class_id',   v_class_id,
    'class_code', v_code
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION create_class(TEXT, TEXT, UUID, UUID, TEXT) TO authenticated;
