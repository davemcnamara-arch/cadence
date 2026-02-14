-- Table to track song pairs that have been dismissed as not-duplicates
CREATE TABLE IF NOT EXISTS dismissed_duplicates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  song_id_a UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  song_id_b UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  dismissed_by UUID NOT NULL REFERENCES auth.users(id),
  dismissed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (song_id_a, song_id_b)
);

-- Always store the smaller UUID in song_id_a for consistent lookups
CREATE OR REPLACE FUNCTION normalize_dismissed_duplicate()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.song_id_a > NEW.song_id_b THEN
    -- Swap so the smaller UUID is always in song_id_a
    DECLARE tmp UUID := NEW.song_id_a;
    BEGIN
      NEW.song_id_a := NEW.song_id_b;
      NEW.song_id_b := tmp;
    END;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_normalize_dismissed_duplicate
  BEFORE INSERT ON dismissed_duplicates
  FOR EACH ROW
  EXECUTE FUNCTION normalize_dismissed_duplicate();

-- RLS: only admins/teachers can dismiss duplicates
ALTER TABLE dismissed_duplicates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Teachers and admins can view dismissed duplicates"
  ON dismissed_duplicates FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role IN ('teacher', 'admin')
    )
  );

CREATE POLICY "Teachers and admins can dismiss duplicates"
  ON dismissed_duplicates FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u WHERE u.id = auth.uid() AND u.role IN ('teacher', 'admin')
    )
  );

-- Function to dismiss a pair as not-duplicates
CREATE OR REPLACE FUNCTION dismiss_duplicate_pair(
  p_song_id_a UUID,
  p_song_id_b UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_a UUID := LEAST(p_song_id_a, p_song_id_b);
  v_b UUID := GREATEST(p_song_id_a, p_song_id_b);
BEGIN
  INSERT INTO dismissed_duplicates (song_id_a, song_id_b, dismissed_by)
  VALUES (v_a, v_b, auth.uid())
  ON CONFLICT (song_id_a, song_id_b) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'message', 'Pair dismissed as not duplicates');
END;
$$;

GRANT EXECUTE ON FUNCTION dismiss_duplicate_pair(UUID, UUID) TO authenticated;

-- Update find_duplicate_song_groups to exclude dismissed pairs
CREATE OR REPLACE FUNCTION find_duplicate_song_groups(
  p_threshold FLOAT DEFAULT 0.4,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  song_id UUID,
  title TEXT,
  artist TEXT,
  approved BOOLEAN,
  created_at TIMESTAMPTZ,
  youtube_url TEXT,
  chords_url TEXT,
  bass_tab_url TEXT,
  drum_notation_url TEXT,
  rating_count BIGINT,
  student_count BIGINT,
  match_song_id UUID,
  match_title TEXT,
  match_artist TEXT,
  similarity_score FLOAT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s1.id AS song_id,
    s1.title,
    s1.artist,
    s1.approved,
    s1.created_at,
    s1.youtube_url,
    s1.chords_url,
    s1.bass_tab_url,
    s1.drum_notation_url,
    (SELECT COUNT(*) FROM song_ratings sr WHERE sr.song_id = s1.id) AS rating_count,
    (SELECT COUNT(*) FROM student_songs ss WHERE ss.song_id = s1.id) AS student_count,
    s2.id AS match_song_id,
    s2.title AS match_title,
    s2.artist AS match_artist,
    ((SIMILARITY(LOWER(s1.title), LOWER(s2.title)) + SIMILARITY(LOWER(s1.artist), LOWER(s2.artist))) / 2.0)::FLOAT AS similarity_score
  FROM songs s1
  CROSS JOIN LATERAL (
    SELECT s.id, s.title, s.artist
    FROM songs s
    WHERE s.id > s1.id  -- avoid duplicate pairs
      AND ((SIMILARITY(LOWER(s.title), LOWER(s1.title)) + SIMILARITY(LOWER(s.artist), LOWER(s1.artist))) / 2.0) > p_threshold
      -- Exclude pairs that have been dismissed
      AND NOT EXISTS (
        SELECT 1 FROM dismissed_duplicates dd
        WHERE dd.song_id_a = LEAST(s1.id, s.id)
          AND dd.song_id_b = GREATEST(s1.id, s.id)
      )
  ) s2
  ORDER BY similarity_score DESC
  LIMIT p_limit;
END;
$$;
