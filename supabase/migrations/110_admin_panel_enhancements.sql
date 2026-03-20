-- ============================================================
-- MIGRATION 110: Admin Panel Enhancements
--
-- 1. Add 'lapsed' to subscriptions status constraint
-- 2. Update get_all_schools to include subscription info
-- 3. Add admin_create_school_for_teacher RPC (manual onboarding)
-- 4. Add admin_get_unassigned_students RPC
-- ============================================================

-- 1. Add 'lapsed' to subscription status values
ALTER TABLE subscriptions DROP CONSTRAINT IF EXISTS subscriptions_status_check;
ALTER TABLE subscriptions ADD CONSTRAINT subscriptions_status_check
  CHECK (status IN ('active', 'trialing', 'expired', 'cancelled', 'lapsed'));

-- ============================================================
-- 2. Update get_all_schools to include subscription info
--    Returns: id, name, join_code, created_at, owner_email,
--             teacher_count, class_count, student_count,
--             subscription_id, subscription_status, plan_type,
--             current_period_end
-- ============================================================
CREATE OR REPLACE FUNCTION get_all_schools()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id   UUID;
  v_user_role TEXT;
  v_result    JSON;
BEGIN
  v_user_id := auth.uid();
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;

  IF v_user_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  SELECT json_build_object(
    'success', true,
    'schools', COALESCE((
      SELECT json_agg(
        json_build_object(
          'id',                  s.id,
          'name',                s.name,
          'join_code',           s.join_code,
          'created_at',          s.created_at,
          'owner_email',         owner.email,
          'teacher_count', (
            SELECT COUNT(*) FROM school_members sm WHERE sm.school_id = s.id
          ),
          'class_count', (
            SELECT COUNT(*)
            FROM classes c
            WHERE c.school_id = s.id AND c.archived = false
          ),
          'student_count', (
            SELECT COUNT(*) FROM school_students ss WHERE ss.school_id = s.id
          ),
          'subscription_id',     sub.id,
          'subscription_status', sub.status,
          'plan_type',           sub.plan_type,
          'current_period_end',  sub.current_period_end
        )
        ORDER BY s.created_at ASC
      )
      FROM schools s
      LEFT JOIN users owner ON owner.id = s.created_by
      LEFT JOIN LATERAL (
        SELECT id, status, plan_type, current_period_end
        FROM subscriptions
        WHERE school_id = s.id
        ORDER BY created_at DESC
        LIMIT 1
      ) sub ON true
    ), '[]'::JSON)
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_all_schools() TO authenticated;

-- ============================================================
-- 3. admin_create_school_for_teacher
--    Admin creates a school + pre-registers teacher + adds
--    a manual subscription. Teacher gets the join code and
--    the admin uses it to onboard them.
-- ============================================================
CREATE OR REPLACE FUNCTION admin_create_school_for_teacher(
  p_school_name  TEXT,
  p_teacher_email TEXT,
  p_teacher_name  TEXT DEFAULT NULL,
  p_plan_type     TEXT DEFAULT 'school',
  p_status        TEXT DEFAULT 'active',
  p_period_end    TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_admin_id        UUID;
  v_teacher_id      UUID;
  v_school_id       UUID;
  v_join_code       TEXT;
  v_sub_id          UUID;
  v_teacher_existed BOOLEAN := false;
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  v_admin_id := auth.uid();

  -- Validate inputs
  IF TRIM(COALESCE(p_school_name, '')) = '' THEN
    RETURN json_build_object('success', false, 'message', 'School name is required');
  END IF;
  IF TRIM(COALESCE(p_teacher_email, '')) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Teacher email is required');
  END IF;
  IF p_plan_type NOT IN ('individual', 'school') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid plan type');
  END IF;
  IF p_status NOT IN ('active', 'trialing', 'expired', 'cancelled', 'lapsed') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid status');
  END IF;

  -- Check if teacher already exists as a user
  SELECT id INTO v_teacher_id
  FROM users
  WHERE LOWER(TRIM(email)) = LOWER(TRIM(p_teacher_email));

  IF v_teacher_id IS NOT NULL THEN
    v_teacher_existed := true;
  ELSE
    -- Pre-register the teacher so they get the teacher role on first sign-in
    INSERT INTO pre_registered_accounts (email, role, name, created_by)
    VALUES (LOWER(TRIM(p_teacher_email)), 'teacher', p_teacher_name, v_admin_id)
    ON CONFLICT (email) DO UPDATE SET name = COALESCE(EXCLUDED.name, pre_registered_accounts.name);
  END IF;

  -- Generate unique 6-char join code
  LOOP
    v_join_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM schools WHERE join_code = v_join_code);
  END LOOP;

  -- Create the school (created by admin)
  INSERT INTO schools (name, join_code, created_by)
  VALUES (TRIM(p_school_name), v_join_code, v_admin_id)
  RETURNING id INTO v_school_id;

  -- If teacher already exists, add them as school admin
  IF v_teacher_id IS NOT NULL THEN
    INSERT INTO school_members (school_id, user_id, school_role)
    VALUES (v_school_id, v_teacher_id, 'admin')
    ON CONFLICT DO NOTHING;
  END IF;

  -- Create the subscription
  INSERT INTO subscriptions (
    school_id, teacher_id, plan_type, status,
    stripe_subscription_id, stripe_customer_id,
    current_period_start, current_period_end
  ) VALUES (
    v_school_id, NULL, p_plan_type, p_status,
    NULL, NULL,
    NOW(), COALESCE(p_period_end, NOW() + INTERVAL '1 year')
  )
  RETURNING id INTO v_sub_id;

  RETURN json_build_object(
    'success',            true,
    'school_id',          v_school_id,
    'join_code',          v_join_code,
    'subscription_id',    v_sub_id,
    'teacher_existed',    v_teacher_existed,
    'message',            'School created successfully'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_create_school_for_teacher(TEXT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ) TO authenticated;

-- ============================================================
-- 4. admin_get_unassigned_students
--    Returns all users with role='student' who have no row
--    in class_members (not enrolled in any class).
--    Includes last_sign_in from auth.users where available.
-- ============================================================
CREATE OR REPLACE FUNCTION admin_get_unassigned_students()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN
    RETURN json_build_object('success', false, 'message', 'Admin access required');
  END IF;

  RETURN (
    SELECT COALESCE(json_agg(
      json_build_object(
        'id',            u.id,
        'email',         u.email,
        'name',          u.name,
        'created_at',    u.created_at,
        'last_sign_in',  au.last_sign_in_at
      )
      ORDER BY u.created_at DESC
    ), '[]'::JSON)
    FROM users u
    LEFT JOIN auth.users au ON au.id = u.id
    WHERE u.role = 'student'
      AND NOT EXISTS (
        SELECT 1 FROM class_members cm WHERE cm.user_id = u.id
      )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION admin_get_unassigned_students() TO authenticated;
