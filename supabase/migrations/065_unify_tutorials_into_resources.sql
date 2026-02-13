-- Migration: Unify song_tutorials into student_resources
--
-- The dual terminology of "tutorial" and "resource" is confusing.
-- A tutorial is just a type of resource. This migration merges
-- song_tutorials data into student_resources (as file_type='tutorial')
-- so there is one unified concept: "resource".

-- ==============================================
-- 1. Add 'tutorial' as a valid file_type
-- ==============================================

-- Drop the existing CHECK constraint and recreate with 'tutorial' included
ALTER TABLE student_resources DROP CONSTRAINT IF EXISTS student_resources_file_type_check;
ALTER TABLE student_resources ADD CONSTRAINT student_resources_file_type_check
  CHECK (file_type IN ('image', 'pdf', 'link', 'tutorial'));

-- ==============================================
-- 2. Migrate song_tutorials data into student_resources
-- ==============================================

-- Map song_tutorials columns to student_resources columns:
--   song_tutorials.url           → student_resources.file_url
--   song_tutorials.title         → student_resources.title (with fallback)
--   song_tutorials.submitted_by_user_id → student_resources.user_id
--   file_type = 'tutorial'
--   All other fields map directly

INSERT INTO student_resources (
  id,
  song_id,
  user_id,
  title,
  description,
  file_url,
  file_type,
  status,
  reviewed_by_user_id,
  reviewed_at,
  instrument_id,
  created_at
)
SELECT
  id,
  song_id,
  submitted_by_user_id,
  COALESCE(title, 'Tutorial Video'),
  NULL,
  url,
  'tutorial',
  status,
  reviewed_by_user_id,
  reviewed_at,
  instrument_id,
  created_at
FROM song_tutorials
WHERE NOT EXISTS (
  -- Avoid duplicates if migration is re-run
  SELECT 1 FROM student_resources sr
  WHERE sr.id = song_tutorials.id
);

-- ==============================================
-- 3. Update the INSERT policy to allow tutorial submissions
-- ==============================================

-- The existing policy only allows students to insert. We need to also
-- allow teachers/admins (since tutorials were insertable by anyone).
DROP POLICY IF EXISTS "Students can submit resources" ON student_resources;
CREATE POLICY "Users can submit resources" ON student_resources
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
  );

-- ==============================================
-- 4. Update get_song_resources to include tutorials
-- ==============================================

-- Drop existing overloads
DROP FUNCTION IF EXISTS get_song_resources(UUID);
DROP FUNCTION IF EXISTS get_song_resources(UUID, UUID);

CREATE OR REPLACE FUNCTION get_song_resources(
  p_song_id UUID,
  p_instrument_id UUID DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  description TEXT,
  file_url TEXT,
  file_type TEXT,
  status TEXT,
  instrument_id UUID,
  instrument_name TEXT,
  contributor_name TEXT,
  created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_is_teacher BOOLEAN;
BEGIN
  SELECT role IN ('teacher', 'admin') INTO v_is_teacher
  FROM users WHERE id = auth.uid();

  RETURN QUERY
  SELECT
    sr.id,
    sr.title,
    sr.description,
    sr.file_url,
    sr.file_type,
    sr.status,
    sr.instrument_id,
    i.name as instrument_name,
    COALESCE(u.name, 'Student') as contributor_name,
    sr.created_at
  FROM student_resources sr
  LEFT JOIN users u ON sr.user_id = u.id
  LEFT JOIN instruments i ON sr.instrument_id = i.id
  WHERE sr.song_id = p_song_id
    AND (sr.status = 'approved' OR v_is_teacher OR sr.user_id = auth.uid())
    AND (p_instrument_id IS NULL OR sr.instrument_id IS NULL OR sr.instrument_id = p_instrument_id)
  ORDER BY
    -- Show tutorials first, then other resources
    CASE WHEN sr.file_type = 'tutorial' THEN 0 ELSE 1 END,
    sr.created_at ASC;
END;
$$;

-- ==============================================
-- 5. Drop tutorial-specific functions (no longer needed)
-- ==============================================

DROP FUNCTION IF EXISTS get_song_tutorials(UUID);
DROP FUNCTION IF EXISTS get_song_tutorials(UUID, UUID);
DROP FUNCTION IF EXISTS approve_song_tutorial(UUID);
DROP FUNCTION IF EXISTS reject_song_tutorial(UUID);
