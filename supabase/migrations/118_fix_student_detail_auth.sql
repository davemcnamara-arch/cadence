-- ============================================================
-- MIGRATION 118: Fix get_student_detail authorization
--
-- Problem:
--   get_student_detail only authorises:
--     1. The student themselves
--     2. A teacher who directly owns a class containing the student
--
--   This means that when a colleague (teacher in the same school)
--   OR a global admin clicks on a student they don't directly
--   teach in the "All Students" tab, the RPC throws
--   "Permission denied" and the UI shows
--   "This student hasn't started any instruments yet."
--
-- Fix:
--   Expand the authorisation check to also allow:
--     3. Global admins  (is_admin())
--     4. Peer teachers who share a school with the student
--        (any teacher who is a school_member of a school that
--         contains one of the student's classes)
--
-- Also updates search_teacher_students so that non-admin teachers
-- in a school context see ALL students in that school (matching
-- the shared-class-visibility behaviour already in place for
-- get_teacher_classes).
-- ============================================================

-- ============================================================
-- 1. Fix get_student_detail authorisation + return full data
--    Returns { progress: [...], songs: [...] } so the UI can
--    display both level information and song lists.
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_student_detail(
  p_student_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id     UUID;
  v_is_authorized BOOLEAN;
  v_result        JSON;
BEGIN
  v_caller_id := auth.uid();

  -- Authorisation: caller must be one of:
  --   1. The student themselves
  --   2. A global admin
  --   3. A teacher who directly teaches a class containing the student
  --   4. A peer teacher who is a school member of any school
  --      that contains one of the student's classes
  SELECT (
    v_caller_id = p_student_id

    OR is_admin()

    OR EXISTS (
      SELECT 1
      FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      WHERE cm.user_id = p_student_id
        AND c.teacher_id = v_caller_id
    )

    OR EXISTS (
      SELECT 1
      FROM class_members cm
      JOIN classes c ON c.id = cm.class_id
      JOIN school_members sm ON sm.school_id = c.school_id
      WHERE cm.user_id = p_student_id
        AND sm.user_id = v_caller_id
    )
  ) INTO v_is_authorized;

  IF NOT v_is_authorized THEN
    RAISE EXCEPTION 'Permission denied: You do not have access to this student''s data';
  END IF;

  -- Return both progress (level info) and songs so the UI can display
  -- instrument cards with level badges as well as song lists.
  SELECT json_build_object(
    'progress', (
      SELECT COALESCE(json_agg(
        json_build_object(
          'id',             sp.id,
          'user_id',        sp.user_id,
          'instrument_id',  sp.instrument_id,
          'current_level',  sp.current_level,
          'current_branch', sp.current_branch,
          'instruments', json_build_object(
            'id',   i.id,
            'name', i.name,
            'icon', i.icon
          )
        )
      ), '[]'::json)
      FROM student_progress sp
      JOIN instruments i ON i.id = sp.instrument_id
      WHERE sp.user_id = p_student_id
    ),
    'songs', (
      SELECT COALESCE(json_agg(
        json_build_object(
          'id',             ss.id,
          'user_id',        ss.user_id,
          'song_id',        ss.song_id,
          'instrument_id',  ss.instrument_id,
          'status',         ss.status,
          'date_started',   ss.date_started,
          'date_completed', ss.date_completed,
          'songs', json_build_object(
            'id',                  s.id,
            'title',               s.title,
            'artist',              s.artist,
            'chords_url',          s.chords_url,
            'bass_tab_url',        s.bass_tab_url,
            'drum_notation_url',   s.drum_notation_url,
            'tutorial_url',        s.tutorial_url,
            'youtube_url',         s.youtube_url
          ),
          'instruments', json_build_object(
            'id',   i.id,
            'name', i.name,
            'icon', i.icon
          ),
          'resource_ratings', json_build_object(
            'chords', COALESCE((
              SELECT json_agg(rr.chords_rating)
              FROM resource_ratings rr
              WHERE rr.student_song_id = ss.id
                AND rr.chords_rating IS NOT NULL
            ), '[]'::json),
            'tutorial', COALESCE((
              SELECT json_agg(rr.tutorial_rating)
              FROM resource_ratings rr
              WHERE rr.student_song_id = ss.id
                AND rr.tutorial_rating IS NOT NULL
            ), '[]'::json)
          )
        )
        ORDER BY ss.date_started DESC
      ), '[]'::json)
      FROM student_songs ss
      JOIN songs s ON s.id = ss.song_id
      JOIN instruments i ON i.id = ss.instrument_id
      WHERE ss.user_id = p_student_id
    )
  ) INTO v_result;

  RETURN v_result;

EXCEPTION
  WHEN OTHERS THEN
    IF SQLERRM LIKE 'Permission denied%' THEN
      RAISE;
    END IF;
    RETURN json_build_object('progress', '[]'::json, 'songs', '[]'::json);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_detail(UUID) TO authenticated;

-- ============================================================
-- 2. Update search_teacher_students so that non-admin teachers
--    in a school context see ALL students in the school
--    (matching the shared-class-visibility behaviour already
--    present in get_teacher_classes).
--
--    Rule:
--      - p_school_id IS NULL  → own students only (no change)
--      - p_school_id IS NOT NULL AND caller is school member
--                             → all students in that school
--    Admins already see everything; no change there.
-- ============================================================
CREATE OR REPLACE FUNCTION search_teacher_students(
  p_school_id UUID DEFAULT NULL
)
RETURNS TABLE (
  user_id    UUID,
  name       TEXT,
  email      TEXT,
  class_id   UUID,
  class_name TEXT,
  joined_at  TIMESTAMPTZ,
  is_pending BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF is_admin() THEN
    -- Active students in any class (optionally scoped to school)
    RETURN QUERY
    SELECT
      u.id   AS user_id,
      u.name,
      u.email,
      c.id   AS class_id,
      c.name AS class_name,
      cm.joined_at,
      FALSE  AS is_pending
    FROM users u
    INNER JOIN class_members cm ON u.id = cm.user_id
    INNER JOIN classes c ON cm.class_id = c.id
    WHERE c.archived IS NOT TRUE
      AND (p_school_id IS NULL OR c.school_id = p_school_id);

    -- Students not linked to any class (only when no school filter)
    IF p_school_id IS NULL THEN
      RETURN QUERY
      SELECT
        u.id   AS user_id,
        u.name,
        u.email,
        NULL::UUID         AS class_id,
        'No Class'::TEXT   AS class_name,
        u.created_at       AS joined_at,
        FALSE              AS is_pending
      FROM users u
      WHERE u.role = 'student'
        AND NOT EXISTS (
          SELECT 1 FROM class_members cm WHERE cm.user_id = u.id
        );
    END IF;

    -- Pending enrollments (optionally scoped to school)
    RETURN QUERY
    SELECT
      NULL::UUID                      AS user_id,
      SPLIT_PART(pe.email, '@', 1)   AS name,
      pe.email,
      c.id                            AS class_id,
      c.name                          AS class_name,
      pe.created_at                   AS joined_at,
      TRUE                            AS is_pending
    FROM pending_enrollments pe
    INNER JOIN classes c ON pe.class_id = c.id
    WHERE c.archived IS NOT TRUE
      AND (p_school_id IS NULL OR c.school_id = p_school_id);

  ELSIF p_school_id IS NOT NULL AND EXISTS (
    -- Caller is a member of the requested school
    SELECT 1 FROM school_members sm
    WHERE sm.school_id = p_school_id AND sm.user_id = auth.uid()
  ) THEN
    -- Non-admin teacher in school context: show ALL students in the school
    RETURN QUERY
    SELECT
      u.id   AS user_id,
      u.name,
      u.email,
      c.id   AS class_id,
      c.name AS class_name,
      cm.joined_at,
      FALSE  AS is_pending
    FROM users u
    INNER JOIN class_members cm ON u.id = cm.user_id
    INNER JOIN classes c ON cm.class_id = c.id
    WHERE c.school_id = p_school_id
      AND c.archived IS NOT TRUE;

    -- Pending enrollments for all classes in the school
    RETURN QUERY
    SELECT
      NULL::UUID                      AS user_id,
      SPLIT_PART(pe.email, '@', 1)   AS name,
      pe.email,
      c.id                            AS class_id,
      c.name                          AS class_name,
      pe.created_at                   AS joined_at,
      TRUE                            AS is_pending
    FROM pending_enrollments pe
    INNER JOIN classes c ON pe.class_id = c.id
    WHERE c.school_id = p_school_id
      AND c.archived IS NOT TRUE;

  ELSE
    -- No school context (or not a school member): own students only
    RETURN QUERY
    SELECT
      u.id   AS user_id,
      u.name,
      u.email,
      c.id   AS class_id,
      c.name AS class_name,
      cm.joined_at,
      FALSE  AS is_pending
    FROM users u
    INNER JOIN class_members cm ON u.id = cm.user_id
    INNER JOIN classes c ON cm.class_id = c.id
    WHERE c.teacher_id = auth.uid()
      AND c.archived IS NOT TRUE;

    -- Pending enrollments for teacher's own classes
    RETURN QUERY
    SELECT
      NULL::UUID                      AS user_id,
      SPLIT_PART(pe.email, '@', 1)   AS name,
      pe.email,
      c.id                            AS class_id,
      c.name                          AS class_name,
      pe.created_at                   AS joined_at,
      TRUE                            AS is_pending
    FROM pending_enrollments pe
    INNER JOIN classes c ON pe.class_id = c.id
    WHERE c.teacher_id = auth.uid()
      AND c.archived IS NOT TRUE;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION search_teacher_students(UUID) TO authenticated;
