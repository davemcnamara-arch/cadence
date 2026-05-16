-- ============================================================
-- MIGRATION 145: Pending co-teachers
--
-- Extends co-teaching (migration 144) to support teachers who
-- haven't signed up yet (exist in pre_registered_accounts).
-- When the pending teacher completes signup, their pending
-- co-teacher records are automatically converted to real ones.
--
-- New objects:
--   - pending_class_co_teachers table (class_id, email)
--   - add_pending_co_teacher(class_id, email) RPC
--   - remove_pending_co_teacher(class_id, email) RPC
--
-- Updated:
--   - get_class_co_teachers() — includes pending records with
--     is_pending: true
--   - complete_pending_teacher_setup() — converts pending
--     co-teacher records when the teacher signs up
-- ============================================================


-- ============================================================
-- 1. pending_class_co_teachers table
-- ============================================================
CREATE TABLE IF NOT EXISTS pending_class_co_teachers (
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  email    TEXT NOT NULL,
  added_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  PRIMARY KEY (class_id, email)
);

ALTER TABLE pending_class_co_teachers ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, DELETE ON pending_class_co_teachers TO authenticated;

-- Class owners can fully manage pending co-teacher records
CREATE POLICY "Class owners can manage pending co-teachers" ON pending_class_co_teachers
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM classes
    WHERE id = class_id AND teacher_id = auth.uid()
  )
);


-- ============================================================
-- 2. add_pending_co_teacher RPC
--    Allowed: class owner or admin.
--    Adds an email-based co-teacher record for a teacher who
--    hasn't signed up yet.
-- ============================================================
CREATE OR REPLACE FUNCTION add_pending_co_teacher(
  p_class_id UUID,
  p_email    TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      UUID := auth.uid();
  v_class_owner_id UUID;
  v_normalized     TEXT := LOWER(TRIM(p_email));
BEGIN
  IF v_normalized = '' OR v_normalized IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Email is required');
  END IF;

  SELECT teacher_id INTO v_class_owner_id FROM classes WHERE id = p_class_id;

  IF v_class_owner_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  IF v_caller_id != v_class_owner_id AND NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Only the class owner can add co-teachers');
  END IF;

  -- If this email already belongs to an active user, reject — use add_co_teacher instead
  IF EXISTS (SELECT 1 FROM users WHERE lower(email) = v_normalized AND role IN ('teacher', 'admin')) THEN
    RETURN json_build_object('success', false, 'message', 'That teacher has already signed up — select them from the active teacher list');
  END IF;

  INSERT INTO pending_class_co_teachers (class_id, email)
  VALUES (p_class_id, v_normalized)
  ON CONFLICT (class_id, email) DO NOTHING;

  RETURN json_build_object('success', true, 'message', 'Co-teacher invite added — they will have access once they log in');
END;
$$;

GRANT EXECUTE ON FUNCTION add_pending_co_teacher(UUID, TEXT) TO authenticated;


-- ============================================================
-- 3. remove_pending_co_teacher RPC
--    Allowed: class owner or admin.
-- ============================================================
CREATE OR REPLACE FUNCTION remove_pending_co_teacher(
  p_class_id UUID,
  p_email    TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id      UUID := auth.uid();
  v_class_owner_id UUID;
BEGIN
  SELECT teacher_id INTO v_class_owner_id FROM classes WHERE id = p_class_id;

  IF v_class_owner_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Class not found');
  END IF;

  IF v_caller_id != v_class_owner_id AND NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Permission denied');
  END IF;

  DELETE FROM pending_class_co_teachers
  WHERE class_id = p_class_id AND lower(email) = lower(trim(p_email));

  RETURN json_build_object('success', true, 'message', 'Pending co-teacher removed');
END;
$$;

GRANT EXECUTE ON FUNCTION remove_pending_co_teacher(UUID, TEXT) TO authenticated;


-- ============================================================
-- 4. Updated get_class_co_teachers()
--    Now returns both active and pending co-teachers.
--    Pending rows have is_pending: true and teacher_id: null.
-- ============================================================
CREATE OR REPLACE FUNCTION get_class_co_teachers(p_class_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result JSON;
BEGIN
  IF NOT is_class_teacher_or_coteacher(p_class_id) AND NOT is_admin() THEN
    RETURN '[]'::json;
  END IF;

  SELECT COALESCE(
    json_agg(
      json_build_object(
        'teacher_id', combined.teacher_id,
        'name',       combined.display_name,
        'email',      combined.email,
        'added_at',   combined.added_at,
        'is_pending', combined.is_pending
      )
      ORDER BY combined.is_pending ASC, combined.display_name ASC
    ),
    '[]'::json
  )
  INTO v_result
  FROM (
    -- Active co-teachers
    SELECT
      u.id                     AS teacher_id,
      u.name                   AS display_name,
      u.email,
      ct.added_at,
      false                    AS is_pending
    FROM class_co_teachers ct
    JOIN users u ON u.id = ct.teacher_id
    WHERE ct.class_id = p_class_id

    UNION ALL

    -- Pending co-teachers (not yet signed up)
    SELECT
      NULL::UUID               AS teacher_id,
      COALESCE(pra.name, pct.email) AS display_name,
      pct.email,
      pct.added_at,
      true                     AS is_pending
    FROM pending_class_co_teachers pct
    LEFT JOIN pre_registered_accounts pra ON lower(pra.email) = lower(pct.email)
    WHERE pct.class_id = p_class_id
  ) combined;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_class_co_teachers(UUID) TO authenticated;


-- ============================================================
-- 5. Updated complete_pending_teacher_setup()
--    Also converts any pending co-teacher records for the
--    newly signed-up teacher's email into real class_co_teachers
--    rows — so co-teaching access is granted automatically.
-- ============================================================
CREATE OR REPLACE FUNCTION complete_pending_teacher_setup(p_email TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id           UUID;
  v_transferred_count INTEGER := 0;
  v_coteacher_count   INTEGER := 0;
  v_normalized        TEXT    := lower(trim(p_email));
BEGIN
  SELECT id INTO v_user_id
  FROM users
  WHERE lower(email) = v_normalized;

  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'User not found');
  END IF;

  -- Transfer owned classes (existing behaviour)
  UPDATE classes
  SET teacher_id = v_user_id, pending_teacher_email = NULL
  WHERE lower(pending_teacher_email) = v_normalized;
  GET DIAGNOSTICS v_transferred_count = ROW_COUNT;

  -- Convert pending co-teacher records to real ones
  INSERT INTO class_co_teachers (class_id, teacher_id)
  SELECT class_id, v_user_id
  FROM pending_class_co_teachers
  WHERE lower(email) = v_normalized
  ON CONFLICT (class_id, teacher_id) DO NOTHING;
  GET DIAGNOSTICS v_coteacher_count = ROW_COUNT;

  DELETE FROM pending_class_co_teachers WHERE lower(email) = v_normalized;

  RETURN json_build_object(
    'success',           true,
    'transferred_classes', v_transferred_count,
    'coteacher_classes', v_coteacher_count
  );
END;
$$;

GRANT EXECUTE ON FUNCTION complete_pending_teacher_setup(TEXT) TO authenticated;
