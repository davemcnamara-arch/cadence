-- Migration: Add schools and school membership
-- Allows teachers to group under a school for school-wide reporting and management

-- Schools table
CREATE TABLE schools (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  join_code TEXT NOT NULL UNIQUE,
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- School members table (teachers and school admins)
CREATE TABLE school_members (
  school_id UUID NOT NULL REFERENCES schools(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  school_role TEXT NOT NULL DEFAULT 'teacher' CHECK (school_role IN ('admin', 'teacher')),
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (school_id, user_id)
);

-- Indexes for performance
CREATE INDEX idx_school_members_user_id ON school_members(user_id);
CREATE INDEX idx_school_members_school_id ON school_members(school_id);

-- RLS policies
ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE school_members ENABLE ROW LEVEL SECURITY;

-- Schools: members can view their school
CREATE POLICY "School members can view their school"
  ON schools FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM school_members
      WHERE school_members.school_id = schools.id
        AND school_members.user_id = auth.uid()
    )
  );

-- Schools: school admins can update their school
CREATE POLICY "School admins can update their school"
  ON schools FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM school_members
      WHERE school_members.school_id = schools.id
        AND school_members.user_id = auth.uid()
        AND school_members.school_role = 'admin'
    )
  );

-- School members: members can view other members of their school
CREATE POLICY "School members can view members of their school"
  ON school_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM school_members sm2
      WHERE sm2.school_id = school_members.school_id
        AND sm2.user_id = auth.uid()
    )
  );

-- ============================================================
-- FUNCTION: create_school
-- Creates a school and adds the caller as school admin
-- ============================================================
CREATE OR REPLACE FUNCTION create_school(p_name TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role TEXT;
  v_user_id UUID;
  v_school_id UUID;
  v_join_code TEXT;
  v_existing_school_id UUID;
BEGIN
  v_user_id := auth.uid();

  -- Only teachers/admins can create schools
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;
  IF v_user_role NOT IN ('teacher', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Only teachers can create schools');
  END IF;

  -- Check caller isn't already in a school
  SELECT school_id INTO v_existing_school_id
  FROM school_members WHERE user_id = v_user_id LIMIT 1;

  IF v_existing_school_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'message', 'You are already a member of a school');
  END IF;

  -- Validate name
  IF p_name IS NULL OR TRIM(p_name) = '' THEN
    RETURN json_build_object('success', false, 'message', 'School name cannot be empty');
  END IF;

  -- Generate unique 6-char join code
  LOOP
    v_join_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM schools WHERE join_code = v_join_code);
  END LOOP;

  -- Create school
  INSERT INTO schools (name, join_code, created_by)
  VALUES (TRIM(p_name), v_join_code, v_user_id)
  RETURNING id INTO v_school_id;

  -- Add creator as school admin
  INSERT INTO school_members (school_id, user_id, school_role)
  VALUES (v_school_id, v_user_id, 'admin');

  RETURN json_build_object(
    'success', true,
    'school_id', v_school_id,
    'join_code', v_join_code,
    'message', 'School created successfully'
  );
END;
$$;

-- ============================================================
-- FUNCTION: join_school
-- Teacher joins an existing school by join code
-- ============================================================
CREATE OR REPLACE FUNCTION join_school(p_join_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role TEXT;
  v_user_id UUID;
  v_school_id UUID;
  v_school_name TEXT;
  v_existing_school_id UUID;
BEGIN
  v_user_id := auth.uid();

  -- Only teachers/admins can join schools
  SELECT role INTO v_user_role FROM users WHERE id = v_user_id;
  IF v_user_role NOT IN ('teacher', 'admin') THEN
    RETURN json_build_object('success', false, 'message', 'Only teachers can join schools');
  END IF;

  -- Check caller isn't already in a school
  SELECT school_id INTO v_existing_school_id
  FROM school_members WHERE user_id = v_user_id LIMIT 1;

  IF v_existing_school_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'message', 'You are already a member of a school');
  END IF;

  -- Find school by join code (case-insensitive)
  SELECT id, name INTO v_school_id, v_school_name
  FROM schools WHERE UPPER(join_code) = UPPER(TRIM(p_join_code));

  IF v_school_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid school code');
  END IF;

  -- Add teacher to school
  INSERT INTO school_members (school_id, user_id, school_role)
  VALUES (v_school_id, v_user_id, 'teacher');

  RETURN json_build_object(
    'success', true,
    'school_id', v_school_id,
    'school_name', v_school_name,
    'message', format('Joined %s successfully', v_school_name)
  );
END;
$$;

-- ============================================================
-- FUNCTION: get_my_school
-- Returns the current user's school info + their role in it
-- ============================================================
CREATE OR REPLACE FUNCTION get_my_school()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_result JSON;
BEGIN
  v_user_id := auth.uid();

  SELECT json_build_object(
    'id', s.id,
    'name', s.name,
    'join_code', s.join_code,
    'created_at', s.created_at,
    'school_role', sm.school_role
  ) INTO v_result
  FROM school_members sm
  JOIN schools s ON s.id = sm.school_id
  WHERE sm.user_id = v_user_id
  LIMIT 1;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: get_school_dashboard
-- Returns school-wide stats and teacher roster
-- ============================================================
CREATE OR REPLACE FUNCTION get_school_dashboard(p_school_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_is_member BOOLEAN;
  v_result JSON;
BEGIN
  v_user_id := auth.uid();

  -- Verify caller is a member of this school
  SELECT EXISTS (
    SELECT 1 FROM school_members
    WHERE school_id = p_school_id AND user_id = v_user_id
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN json_build_object('success', false, 'message', 'Access denied');
  END IF;

  SELECT json_build_object(
    'success', true,
    'teachers', (
      SELECT json_agg(
        json_build_object(
          'user_id', u.id,
          'name', u.name,
          'email', u.email,
          'school_role', sm.school_role,
          'joined_at', sm.joined_at,
          'class_count', (
            SELECT COUNT(*) FROM classes c
            WHERE c.teacher_id = u.id AND c.archived = false
          ),
          'student_count', (
            SELECT COUNT(DISTINCT cm.user_id)
            FROM classes c
            JOIN class_members cm ON cm.class_id = c.id
            WHERE c.teacher_id = u.id AND c.archived = false
          )
        )
        ORDER BY sm.school_role DESC, u.name ASC
      )
      FROM school_members sm
      JOIN users u ON u.id = sm.user_id
      WHERE sm.school_id = p_school_id
    ),
    'stats', (
      SELECT json_build_object(
        'teacher_count', (
          SELECT COUNT(*) FROM school_members WHERE school_id = p_school_id
        ),
        'class_count', (
          SELECT COUNT(*)
          FROM classes c
          JOIN school_members sm ON sm.user_id = c.teacher_id
          WHERE sm.school_id = p_school_id AND c.archived = false
        ),
        'student_count', (
          SELECT COUNT(DISTINCT cm.user_id)
          FROM classes c
          JOIN school_members sm ON sm.user_id = c.teacher_id
          JOIN class_members cm ON cm.class_id = c.id
          WHERE sm.school_id = p_school_id AND c.archived = false
        ),
        'instrument_counts', (
          SELECT json_agg(
            json_build_object('name', i.name, 'icon', i.icon, 'count', sp_counts.cnt)
            ORDER BY sp_counts.cnt DESC
          )
          FROM (
            SELECT sp.instrument_id, COUNT(DISTINCT sp.user_id) AS cnt
            FROM student_progress sp
            WHERE sp.user_id IN (
              SELECT DISTINCT cm.user_id
              FROM classes c
              JOIN school_members sm ON sm.user_id = c.teacher_id
              JOIN class_members cm ON cm.class_id = c.id
              WHERE sm.school_id = p_school_id
            )
            GROUP BY sp.instrument_id
          ) sp_counts
          JOIN instruments i ON i.id = sp_counts.instrument_id
        )
      )
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: get_school_students
-- Returns all students across all classes in the school
-- ============================================================
CREATE OR REPLACE FUNCTION get_school_students(p_school_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_is_member BOOLEAN;
  v_result JSON;
BEGIN
  v_user_id := auth.uid();

  SELECT EXISTS (
    SELECT 1 FROM school_members
    WHERE school_id = p_school_id AND user_id = v_user_id
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RETURN json_build_object('success', false, 'message', 'Access denied');
  END IF;

  SELECT json_build_object(
    'success', true,
    'students', (
      SELECT json_agg(
        json_build_object(
          'user_id', u.id,
          'name', u.name,
          'email', u.email,
          'class_name', c.name,
          'teacher_name', t.name,
          'instruments', (
            SELECT json_agg(
              json_build_object(
                'instrument_name', i.name,
                'instrument_icon', i.icon,
                'current_level', sp.current_level
              )
              ORDER BY i.display_order
            )
            FROM student_progress sp
            JOIN instruments i ON i.id = sp.instrument_id
            WHERE sp.user_id = u.id
          ),
          'songs_learning', (
            SELECT COUNT(*) FROM student_songs ss
            WHERE ss.user_id = u.id AND ss.status = 'learning'
          ),
          'songs_mastered', (
            SELECT COUNT(*) FROM student_songs ss
            WHERE ss.user_id = u.id AND ss.status = 'mastered'
          )
        )
        ORDER BY u.name ASC
      )
      FROM (
        SELECT DISTINCT cm.user_id, c.name, c.teacher_id
        FROM classes c
        JOIN school_members sm ON sm.user_id = c.teacher_id
        JOIN class_members cm ON cm.class_id = c.id
        WHERE sm.school_id = p_school_id AND c.archived = false
      ) class_data
      JOIN users u ON u.id = class_data.user_id
      JOIN classes c ON c.name = class_data.name AND c.teacher_id = class_data.teacher_id
      JOIN users t ON t.id = class_data.teacher_id
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ============================================================
-- FUNCTION: leave_school
-- Remove yourself from a school
-- ============================================================
CREATE OR REPLACE FUNCTION leave_school(p_school_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_school_role TEXT;
  v_admin_count INTEGER;
BEGIN
  v_user_id := auth.uid();

  SELECT school_role INTO v_school_role
  FROM school_members
  WHERE school_id = p_school_id AND user_id = v_user_id;

  IF v_school_role IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'You are not a member of this school');
  END IF;

  -- Prevent last admin from leaving
  IF v_school_role = 'admin' THEN
    SELECT COUNT(*) INTO v_admin_count
    FROM school_members
    WHERE school_id = p_school_id AND school_role = 'admin';

    IF v_admin_count <= 1 THEN
      RETURN json_build_object(
        'success', false,
        'message', 'You are the only admin. Promote another teacher to admin before leaving.'
      );
    END IF;
  END IF;

  DELETE FROM school_members WHERE school_id = p_school_id AND user_id = v_user_id;

  RETURN json_build_object('success', true, 'message', 'You have left the school');
END;
$$;

-- ============================================================
-- FUNCTION: update_school_member_role
-- School admin promotes/demotes a teacher within the school
-- ============================================================
CREATE OR REPLACE FUNCTION update_school_member_role(
  p_school_id UUID,
  p_user_id UUID,
  p_new_role TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_role TEXT;
BEGIN
  v_caller_id := auth.uid();

  IF p_new_role NOT IN ('admin', 'teacher') THEN
    RETURN json_build_object('success', false, 'message', 'Invalid role');
  END IF;

  -- Caller must be school admin
  SELECT school_role INTO v_caller_role
  FROM school_members
  WHERE school_id = p_school_id AND user_id = v_caller_id;

  IF v_caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Only school admins can change roles');
  END IF;

  -- Target must be in school
  IF NOT EXISTS (
    SELECT 1 FROM school_members WHERE school_id = p_school_id AND user_id = p_user_id
  ) THEN
    RETURN json_build_object('success', false, 'message', 'User is not in this school');
  END IF;

  UPDATE school_members SET school_role = p_new_role
  WHERE school_id = p_school_id AND user_id = p_user_id;

  RETURN json_build_object('success', true, 'message', 'Role updated');
END;
$$;

-- ============================================================
-- FUNCTION: remove_from_school
-- School admin removes a teacher from the school
-- ============================================================
CREATE OR REPLACE FUNCTION remove_from_school(p_school_id UUID, p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_role TEXT;
  v_target_name TEXT;
BEGIN
  v_caller_id := auth.uid();

  -- Caller must be school admin
  SELECT school_role INTO v_caller_role
  FROM school_members
  WHERE school_id = p_school_id AND user_id = v_caller_id;

  IF v_caller_role != 'admin' THEN
    RETURN json_build_object('success', false, 'message', 'Only school admins can remove members');
  END IF;

  -- Cannot remove yourself this way
  IF p_user_id = v_caller_id THEN
    RETURN json_build_object('success', false, 'message', 'Use "Leave School" to remove yourself');
  END IF;

  SELECT name INTO v_target_name FROM users WHERE id = p_user_id;

  DELETE FROM school_members WHERE school_id = p_school_id AND user_id = p_user_id;

  RETURN json_build_object(
    'success', true,
    'message', format('%s has been removed from the school', v_target_name)
  );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION create_school(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION join_school(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_my_school() TO authenticated;
GRANT EXECUTE ON FUNCTION get_school_dashboard(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_school_students(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION leave_school(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION update_school_member_role(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION remove_from_school(UUID, UUID) TO authenticated;
