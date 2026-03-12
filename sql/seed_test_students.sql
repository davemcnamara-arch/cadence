-- ============================================================
-- TEST HELPER: Seed fake student accounts into a class
--
-- Run this in the Supabase SQL Editor (runs as service_role,
-- so it bypasses RLS and can write to auth.users).
--
-- Usage:
--   1. Replace YOUR_CLASS_ID_HERE with the UUID of the class
--      you want to fill (find it in the classes table).
--   2. Set v_count to the number of students you want to add.
--   3. Run the script — it is idempotent (ON CONFLICT DO NOTHING).
--   4. After testing, clean up with the DELETE block at the bottom.
-- ============================================================

DO $$
DECLARE
  v_class_id_text TEXT := '7cf41d29-6ac8-4af1-9ee2-2c7c399be779';
  v_count     INT  := 14;                          -- students to add
  v_class_id  UUID;
  v_user_id   UUID;
  v_email     TEXT;
  v_name      TEXT;
  i           INT;
BEGIN
  IF v_class_id_text = 'YOUR_CLASS_ID_HERE' THEN
    RAISE EXCEPTION 'Replace YOUR_CLASS_ID_HERE with your actual class UUID. Run: SELECT id, name FROM classes WHERE archived = false;';
  END IF;
  v_class_id := v_class_id_text::UUID;
  FOR i IN 1 .. v_count LOOP
    v_user_id := gen_random_uuid();
    v_email   := format('test.student%s+cadence@example.com', i);
    v_name    := format('Test Student %s', i);

    -- 1. Create the auth identity (service_role only)
    INSERT INTO auth.users (
      id,
      email,
      encrypted_password,
      email_confirmed_at,
      created_at,
      updated_at,
      aud,
      role
    )
    VALUES (
      v_user_id,
      v_email,
      -- bcrypt hash of 'TestPassword1!' — never used for real login
      crypt('TestPassword1!', gen_salt('bf')),
      NOW(),
      NOW(),
      NOW(),
      'authenticated',
      'authenticated'
    )
    ON CONFLICT (email) DO NOTHING;

    -- Retrieve the id in case the row already existed
    SELECT id INTO v_user_id
    FROM auth.users
    WHERE email = v_email;

    -- 2. Create the public profile
    INSERT INTO public.users (id, email, name, role)
    VALUES (v_user_id, v_email, v_name, 'student')
    ON CONFLICT (id) DO NOTHING;

    -- 3. Enroll in the class
    INSERT INTO class_members (class_id, user_id, joined_at)
    VALUES (v_class_id, v_user_id, NOW())
    ON CONFLICT (class_id, user_id) DO NOTHING;

  END LOOP;

  RAISE NOTICE 'Done — attempted to add % students to class %', v_count, v_class_id;
END $$;


-- ============================================================
-- CLEANUP (run separately after testing)
-- Removes all rows whose email matches the test pattern.
-- ============================================================
-- DELETE FROM class_members
-- WHERE user_id IN (
--   SELECT id FROM public.users
--   WHERE email LIKE 'test.student%+cadence@example.com'
-- );
--
-- DELETE FROM public.users
-- WHERE email LIKE 'test.student%+cadence@example.com';
--
-- DELETE FROM auth.users
-- WHERE email LIKE 'test.student%+cadence@example.com';
