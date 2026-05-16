-- ============================================================
-- DEMO CLASS SEED DATA — Conference Demo 2025
-- ============================================================
--
-- Creates 8 ghost student accounts, a demo class, and
-- realistic song-progress data for a live conference demo.
-- Does NOT touch any real student or teacher data.
--
-- HOW TO SET YOUR TEACHER ACCOUNT
--   Edit the variable below:
--     v_teacher_email TEXT := 'your.email@example.com';
--
-- HOW TO RUN
--   Supabase dashboard → SQL Editor → paste and run, OR:
--     supabase db execute --file supabase/seeds/demo_class_seed.sql
--
-- HOW TO ROLL BACK (removes everything created by this script)
--   Step 1 – remove the ghost students (cascades to all their data):
--     DELETE FROM auth.users
--     WHERE email LIKE '%.demo@cadencemusic.app';
--
--   Step 2 – remove the demo class (students are already gone):
--     DELETE FROM classes
--     WHERE name = 'Demo Class — Conference 2025';
--
--   The ON DELETE CASCADE chains handle the rest:
--     auth.users → public.users
--       → class_members, school_students
--       → student_progress, student_songs, song_ratings
-- ============================================================

BEGIN;

DO $$
DECLARE
  -- ── CONFIG: set your teacher email here ──────────────────
  v_teacher_email  TEXT := 'your.email@example.com';
  -- ─────────────────────────────────────────────────────────

  v_teacher_id  UUID;
  v_school_id   UUID;
  v_class_id    UUID;
  v_class_code  TEXT;

  -- Instrument IDs (resolved at runtime)
  v_guitar_id   UUID;
  v_bass_id     UUID;
  v_piano_id    UUID;
  v_drums_id    UUID;
  v_vocals_id   UUID;

  -- Ghost student UUIDs — new rows in auth.users + public.users
  v_alex    UUID := gen_random_uuid();  -- Guitar,         Level 1 (beginner)
  v_jamie   UUID := gen_random_uuid();  -- Guitar,         Level 2 (intermediate)
  v_sam     UUID := gen_random_uuid();  -- Guitar,         Level 3 (intermediate)
  v_casey   UUID := gen_random_uuid();  -- Piano/Keyboard, Level 1 (beginner)
  v_jordan  UUID := gen_random_uuid();  -- Piano/Keyboard, Level 2 (intermediate)
  v_morgan  UUID := gen_random_uuid();  -- Bass Guitar,    Level 2 (intermediate)
  v_riley   UUID := gen_random_uuid();  -- Drums,          Level 1 (beginner)
  v_taylor  UUID := gen_random_uuid();  -- Vocals,         Level 2 (intermediate)

  -- Sample song IDs drawn from the live library at run time
  v_songs   UUID[];

BEGIN

  -- ── Resolve teacher ───────────────────────────────────────
  SELECT id INTO v_teacher_id
  FROM users
  WHERE email = v_teacher_email;

  IF v_teacher_id IS NULL THEN
    RAISE EXCEPTION
      'Teacher not found for email "%". Edit v_teacher_email at the top of this script.',
      v_teacher_email;
  END IF;

  -- ── Resolve school ────────────────────────────────────────
  SELECT id INTO v_school_id
  FROM schools
  WHERE name = 'Test School'
  LIMIT 1;

  IF v_school_id IS NULL THEN
    RAISE EXCEPTION
      'School "Test School" not found. Create it first or adjust the school name lookup.';
  END IF;

  -- ── Resolve instruments ───────────────────────────────────
  SELECT id INTO v_guitar_id  FROM instruments WHERE name = 'Guitar';
  SELECT id INTO v_bass_id    FROM instruments WHERE name = 'Bass Guitar';
  SELECT id INTO v_piano_id   FROM instruments WHERE name = 'Piano/Keyboard';
  SELECT id INTO v_drums_id   FROM instruments WHERE name = 'Drums';
  SELECT id INTO v_vocals_id  FROM instruments WHERE name = 'Vocals';

  IF v_guitar_id IS NULL OR v_bass_id IS NULL OR v_piano_id IS NULL
     OR v_drums_id IS NULL OR v_vocals_id IS NULL THEN
    RAISE EXCEPTION 'One or more instruments missing from the instruments table.';
  END IF;

  -- ── Sample songs from the live library ───────────────────
  -- 8 slots are needed. Songs are chosen randomly each run so
  -- the ratings look natural rather than always the same titles.
  SELECT ARRAY(
    SELECT id
    FROM   songs
    WHERE  approved   = true
    AND    deleted_at IS NULL
    ORDER  BY RANDOM()
    LIMIT  8
  ) INTO v_songs;

  IF array_length(v_songs, 1) < 8 THEN
    RAISE EXCEPTION
      'Need at least 8 approved songs in the library (found %). Add songs before running this seed.',
      COALESCE(array_length(v_songs, 1), 0);
  END IF;

  -- ── Generate a unique class code ──────────────────────────
  LOOP
    v_class_code := upper(
      substring(md5(random()::text || clock_timestamp()::text) FROM 1 FOR 6)
    );
    EXIT WHEN NOT EXISTS (SELECT 1 FROM classes WHERE class_code = v_class_code);
  END LOOP;

  -- ════════════════════════════════════════════════════════════
  -- 1. auth.users — ghost accounts (no password, confirmed)
  --    These students will never log in; email_confirmed_at is
  --    set so they don't show as pending in the auth dashboard.
  -- ════════════════════════════════════════════════════════════
  INSERT INTO auth.users (
    id, aud, role, email,
    encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  ) VALUES
    (v_alex,   'authenticated', 'authenticated', 'alex.demo@cadencemusic.app',
     '', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW()),
    (v_jamie,  'authenticated', 'authenticated', 'jamie.demo@cadencemusic.app',
     '', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW()),
    (v_sam,    'authenticated', 'authenticated', 'sam.demo@cadencemusic.app',
     '', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW()),
    (v_casey,  'authenticated', 'authenticated', 'casey.demo@cadencemusic.app',
     '', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW()),
    (v_jordan, 'authenticated', 'authenticated', 'jordan.demo@cadencemusic.app',
     '', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW()),
    (v_morgan, 'authenticated', 'authenticated', 'morgan.demo@cadencemusic.app',
     '', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW()),
    (v_riley,  'authenticated', 'authenticated', 'riley.demo@cadencemusic.app',
     '', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW()),
    (v_taylor, 'authenticated', 'authenticated', 'taylor.demo@cadencemusic.app',
     '', NOW(), '{"provider":"email","providers":["email"]}', '{}', NOW(), NOW());

  -- ════════════════════════════════════════════════════════════
  -- 2. public.users — profile rows
  -- ════════════════════════════════════════════════════════════
  INSERT INTO users (id, email, name, role) VALUES
    (v_alex,   'alex.demo@cadencemusic.app',   'Alex Rivera',    'student'),
    (v_jamie,  'jamie.demo@cadencemusic.app',  'Jamie Chen',     'student'),
    (v_sam,    'sam.demo@cadencemusic.app',    'Sam Torres',     'student'),
    (v_casey,  'casey.demo@cadencemusic.app',  'Casey Kim',      'student'),
    (v_jordan, 'jordan.demo@cadencemusic.app', 'Jordan Lee',     'student'),
    (v_morgan, 'morgan.demo@cadencemusic.app', 'Morgan Davis',   'student'),
    (v_riley,  'riley.demo@cadencemusic.app',  'Riley Martinez', 'student'),
    (v_taylor, 'taylor.demo@cadencemusic.app', 'Taylor Wong',    'student');

  -- ════════════════════════════════════════════════════════════
  -- 3. Demo class
  --    school_id is also auto-set by the set_class_school_id
  --    trigger, but we pass it explicitly for clarity.
  -- ════════════════════════════════════════════════════════════
  v_class_id := gen_random_uuid();

  INSERT INTO classes (id, class_code, name, teacher_id, year_level, school_id)
  VALUES (
    v_class_id,
    v_class_code,
    'Demo Class — Conference 2025',
    v_teacher_id,
    'Mixed',
    v_school_id
  );

  -- ════════════════════════════════════════════════════════════
  -- 4. Enroll students in the class
  --    The trg_auto_assign_student_to_school trigger will also
  --    insert these students into school_students automatically.
  -- ════════════════════════════════════════════════════════════
  INSERT INTO class_members (class_id, user_id) VALUES
    (v_class_id, v_alex),
    (v_class_id, v_jamie),
    (v_class_id, v_sam),
    (v_class_id, v_casey),
    (v_class_id, v_jordan),
    (v_class_id, v_morgan),
    (v_class_id, v_riley),
    (v_class_id, v_taylor);

  -- ════════════════════════════════════════════════════════════
  -- 5. school_students — explicit assignment to 'Test School'
  --    ON CONFLICT DO NOTHING covers the auto-trigger above.
  -- ════════════════════════════════════════════════════════════
  INSERT INTO school_students (school_id, user_id) VALUES
    (v_school_id, v_alex),
    (v_school_id, v_jamie),
    (v_school_id, v_sam),
    (v_school_id, v_casey),
    (v_school_id, v_jordan),
    (v_school_id, v_morgan),
    (v_school_id, v_riley),
    (v_school_id, v_taylor)
  ON CONFLICT (school_id, user_id) DO NOTHING;

  -- ════════════════════════════════════════════════════════════
  -- 6. student_progress — instrument + current level
  -- ════════════════════════════════════════════════════════════
  INSERT INTO student_progress (user_id, instrument_id, current_level) VALUES
    (v_alex,   v_guitar_id, 1),  -- beginner guitarist
    (v_jamie,  v_guitar_id, 2),  -- intermediate guitarist
    (v_sam,    v_guitar_id, 3),  -- stronger guitarist
    (v_casey,  v_piano_id,  1),  -- beginner pianist
    (v_jordan, v_piano_id,  2),  -- intermediate pianist
    (v_morgan, v_bass_id,   2),  -- intermediate bassist
    (v_riley,  v_drums_id,  1),  -- beginner drummer
    (v_taylor, v_vocals_id, 2);  -- intermediate vocalist

  -- ════════════════════════════════════════════════════════════
  -- 7. student_songs — what each student is learning / has mastered
  --
  --    Each student uses distinct song slots so the UNIQUE
  --    constraint on (user_id, song_id, instrument_id) is never
  --    violated. Different instruments on the same song are fine.
  --
  --    Guitar students  (Alex, Jamie, Sam):  slots [1..6]
  --    Piano students   (Casey, Jordan):     slots [1..5]
  --    Bassist (Morgan):                     slots [3..6]
  --    Drummer (Riley):                      slots [5..7]
  --    Vocalist (Taylor):                    slots [1,2,6,7]
  --
  --    Beginners have fewer songs and more "learning"; advanced
  --    students have more "mastered" entries.
  -- ════════════════════════════════════════════════════════════
  INSERT INTO student_songs
    (user_id, song_id, instrument_id, status, date_started, date_completed)
  VALUES
    -- Alex (guitar L1) — 3 songs, still mostly learning
    (v_alex, v_songs[1], v_guitar_id, 'learning', NOW() - INTERVAL '8 weeks',  NULL),
    (v_alex, v_songs[2], v_guitar_id, 'learning', NOW() - INTERVAL '4 weeks',  NULL),
    (v_alex, v_songs[3], v_guitar_id, 'mastered', NOW() - INTERVAL '12 weeks', NOW() - INTERVAL '3 weeks'),

    -- Jamie (guitar L2) — 5 songs, mix of learning/mastered
    (v_jamie, v_songs[1], v_guitar_id, 'mastered', NOW() - INTERVAL '16 weeks', NOW() - INTERVAL '8 weeks'),
    (v_jamie, v_songs[2], v_guitar_id, 'mastered', NOW() - INTERVAL '12 weeks', NOW() - INTERVAL '5 weeks'),
    (v_jamie, v_songs[3], v_guitar_id, 'learning', NOW() - INTERVAL '6 weeks',  NULL),
    (v_jamie, v_songs[4], v_guitar_id, 'learning', NOW() - INTERVAL '3 weeks',  NULL),
    (v_jamie, v_songs[5], v_guitar_id, 'learning', NOW() - INTERVAL '1 week',   NULL),

    -- Sam (guitar L3) — 6 songs, majority mastered
    (v_sam, v_songs[1], v_guitar_id, 'mastered', NOW() - INTERVAL '24 weeks', NOW() - INTERVAL '16 weeks'),
    (v_sam, v_songs[2], v_guitar_id, 'mastered', NOW() - INTERVAL '18 weeks', NOW() - INTERVAL '10 weeks'),
    (v_sam, v_songs[3], v_guitar_id, 'mastered', NOW() - INTERVAL '14 weeks', NOW() - INTERVAL '7 weeks'),
    (v_sam, v_songs[4], v_guitar_id, 'mastered', NOW() - INTERVAL '8 weeks',  NOW() - INTERVAL '2 weeks'),
    (v_sam, v_songs[5], v_guitar_id, 'learning', NOW() - INTERVAL '4 weeks',  NULL),
    (v_sam, v_songs[6], v_guitar_id, 'learning', NOW() - INTERVAL '2 weeks',  NULL),

    -- Casey (piano L1) — 3 songs, beginner pace
    (v_casey, v_songs[1], v_piano_id, 'learning', NOW() - INTERVAL '6 weeks',  NULL),
    (v_casey, v_songs[2], v_piano_id, 'learning', NOW() - INTERVAL '3 weeks',  NULL),
    (v_casey, v_songs[3], v_piano_id, 'mastered', NOW() - INTERVAL '10 weeks', NOW() - INTERVAL '2 weeks'),

    -- Jordan (piano L2) — 5 songs
    (v_jordan, v_songs[1], v_piano_id, 'mastered', NOW() - INTERVAL '14 weeks', NOW() - INTERVAL '7 weeks'),
    (v_jordan, v_songs[2], v_piano_id, 'mastered', NOW() - INTERVAL '10 weeks', NOW() - INTERVAL '3 weeks'),
    (v_jordan, v_songs[3], v_piano_id, 'learning', NOW() - INTERVAL '5 weeks',  NULL),
    (v_jordan, v_songs[4], v_piano_id, 'learning', NOW() - INTERVAL '2 weeks',  NULL),
    (v_jordan, v_songs[5], v_piano_id, 'learning', NOW() - INTERVAL '1 week',   NULL),

    -- Morgan (bass L2) — 4 songs
    (v_morgan, v_songs[3], v_bass_id, 'mastered', NOW() - INTERVAL '12 weeks', NOW() - INTERVAL '5 weeks'),
    (v_morgan, v_songs[4], v_bass_id, 'mastered', NOW() - INTERVAL '8 weeks',  NOW() - INTERVAL '2 weeks'),
    (v_morgan, v_songs[5], v_bass_id, 'learning', NOW() - INTERVAL '4 weeks',  NULL),
    (v_morgan, v_songs[6], v_bass_id, 'learning', NOW() - INTERVAL '1 week',   NULL),

    -- Riley (drums L1) — 3 songs, all still learning
    (v_riley, v_songs[5], v_drums_id, 'learning', NOW() - INTERVAL '7 weeks', NULL),
    (v_riley, v_songs[6], v_drums_id, 'learning', NOW() - INTERVAL '4 weeks', NULL),
    (v_riley, v_songs[7], v_drums_id, 'learning', NOW() - INTERVAL '1 week',  NULL),

    -- Taylor (vocals L2) — 4 songs
    (v_taylor, v_songs[1], v_vocals_id, 'mastered', NOW() - INTERVAL '11 weeks', NOW() - INTERVAL '4 weeks'),
    (v_taylor, v_songs[2], v_vocals_id, 'mastered', NOW() - INTERVAL '7 weeks',  NOW() - INTERVAL '1 week'),
    (v_taylor, v_songs[6], v_vocals_id, 'learning', NOW() - INTERVAL '3 weeks',  NULL),
    (v_taylor, v_songs[7], v_vocals_id, 'learning', NOW() - INTERVAL '1 week',   NULL);

  -- ════════════════════════════════════════════════════════════
  -- 8. song_ratings — self-assessment
  --
  --    Only songs that appear in each student's student_songs list
  --    are rated here (realistic: you rate what you've worked on).
  --    Not every student has rated every song — beginners rate
  --    less, experienced students rate more.
  --    teacher_reviewed = true means the teacher has signed off.
  --
  --    The UNIQUE constraint is (song_id, instrument_id, user_id).
  -- ════════════════════════════════════════════════════════════
  INSERT INTO song_ratings
    (song_id, instrument_id, assessed_level, user_id,
     checklist_responses_json, teacher_reviewed, date_graded)
  VALUES
    -- Alex (guitar, has songs[1,2,3]): rated 2 of 3
    (v_songs[1], v_guitar_id, 1, v_alex, '{}', false, NOW() - INTERVAL '7 weeks'),
    (v_songs[3], v_guitar_id, 1, v_alex, '{}', true,  NOW() - INTERVAL '3 weeks'),

    -- Jamie (guitar, has songs[1,2,3,4,5]): rated 4 of 5
    (v_songs[1], v_guitar_id, 2, v_jamie, '{}', true,  NOW() - INTERVAL '15 weeks'),
    (v_songs[2], v_guitar_id, 2, v_jamie, '{}', true,  NOW() - INTERVAL '11 weeks'),
    (v_songs[3], v_guitar_id, 2, v_jamie, '{}', true,  NOW() - INTERVAL '5 weeks'),
    (v_songs[4], v_guitar_id, 1, v_jamie, '{}', false, NOW() - INTERVAL '2 weeks'),

    -- Sam (guitar, has songs[1,2,3,4,5,6]): rated 4 of 6
    (v_songs[1], v_guitar_id, 3, v_sam, '{}', true,  NOW() - INTERVAL '23 weeks'),
    (v_songs[2], v_guitar_id, 3, v_sam, '{}', true,  NOW() - INTERVAL '17 weeks'),
    (v_songs[3], v_guitar_id, 2, v_sam, '{}', true,  NOW() - INTERVAL '13 weeks'),
    (v_songs[4], v_guitar_id, 3, v_sam, '{}', true,  NOW() - INTERVAL '7 weeks'),

    -- Casey (piano, has songs[1,2,3]): rated 1 of 3 (very new)
    (v_songs[3], v_piano_id, 1, v_casey, '{}', false, NOW() - INTERVAL '8 weeks'),

    -- Jordan (piano, has songs[1,2,3,4,5]): rated 4 of 5
    (v_songs[1], v_piano_id, 2, v_jordan, '{}', true,  NOW() - INTERVAL '13 weeks'),
    (v_songs[2], v_piano_id, 2, v_jordan, '{}', true,  NOW() - INTERVAL '9 weeks'),
    (v_songs[3], v_piano_id, 1, v_jordan, '{}', true,  NOW() - INTERVAL '4 weeks'),
    (v_songs[4], v_piano_id, 2, v_jordan, '{}', false, NOW() - INTERVAL '1 week'),

    -- Morgan (bass, has songs[3,4,5,6]): rated 3 of 4
    (v_songs[3], v_bass_id, 2, v_morgan, '{}', true,  NOW() - INTERVAL '11 weeks'),
    (v_songs[4], v_bass_id, 2, v_morgan, '{}', true,  NOW() - INTERVAL '7 weeks'),
    (v_songs[5], v_bass_id, 1, v_morgan, '{}', false, NOW() - INTERVAL '3 weeks'),

    -- Riley (drums, has songs[5,6,7]): rated 1 of 3 (beginner)
    (v_songs[6], v_drums_id, 1, v_riley, '{}', false, NOW() - INTERVAL '5 weeks'),

    -- Taylor (vocals, has songs[1,2,6,7]): rated 3 of 4
    (v_songs[1], v_vocals_id, 2, v_taylor, '{}', true,  NOW() - INTERVAL '10 weeks'),
    (v_songs[2], v_vocals_id, 2, v_taylor, '{}', true,  NOW() - INTERVAL '6 weeks'),
    (v_songs[7], v_vocals_id, 1, v_taylor, '{}', false, NOW() - INTERVAL '2 weeks');

  RAISE NOTICE '✓ Demo seed complete.';
  RAISE NOTICE '  Class name : Demo Class — Conference 2025';
  RAISE NOTICE '  Class code : %', v_class_code;
  RAISE NOTICE '  Teacher    : %', v_teacher_email;
  RAISE NOTICE '  School     : Test School';
  RAISE NOTICE '  Students   : 8 ghost accounts created';
  RAISE NOTICE '';
  RAISE NOTICE 'To roll back:';
  RAISE NOTICE '  DELETE FROM auth.users WHERE email LIKE ''%%.demo@cadencemusic.app'';';
  RAISE NOTICE '  DELETE FROM classes WHERE name = ''Demo Class — Conference 2025'';';

END $$;

COMMIT;
