-- Enable the pg_trgm extension for fuzzy text matching
CREATE EXTENSION IF NOT EXISTS pg_trgm SCHEMA public;

-- Find potential duplicate songs using trigram similarity
-- Returns groups of songs that look like duplicates
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
  ) s2
  ORDER BY similarity_score DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION find_duplicate_song_groups(FLOAT, INTEGER) TO authenticated;

COMMENT ON FUNCTION find_duplicate_song_groups IS 'Finds pairs of songs that are potential duplicates based on trigram similarity of title and artist.';


-- Merge two songs: reassign all related data from source to target, then delete source
CREATE OR REPLACE FUNCTION merge_songs(
  p_keep_song_id UUID,
  p_delete_song_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_keep_song RECORD;
  v_delete_song RECORD;
  v_ratings_moved INTEGER := 0;
  v_student_songs_moved INTEGER := 0;
  v_tutorials_moved INTEGER := 0;
  v_resources_moved INTEGER := 0;
  v_pending_links_moved INTEGER := 0;
BEGIN
  -- Validate both songs exist
  SELECT * INTO v_keep_song FROM songs WHERE id = p_keep_song_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Song to keep not found');
  END IF;

  SELECT * INTO v_delete_song FROM songs WHERE id = p_delete_song_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Song to merge/delete not found');
  END IF;

  IF p_keep_song_id = p_delete_song_id THEN
    RETURN jsonb_build_object('success', false, 'message', 'Cannot merge a song with itself');
  END IF;

  -- Fill in missing resource URLs on the keeper from the song being deleted
  UPDATE songs SET
    youtube_url = COALESCE(songs.youtube_url, v_delete_song.youtube_url),
    chords_url = COALESCE(songs.chords_url, v_delete_song.chords_url),
    bass_tab_url = COALESCE(songs.bass_tab_url, v_delete_song.bass_tab_url),
    drum_notation_url = COALESCE(songs.drum_notation_url, v_delete_song.drum_notation_url),
    tutorial_url = COALESCE(songs.tutorial_url, v_delete_song.tutorial_url),
    thumbnail = COALESCE(songs.thumbnail, v_delete_song.thumbnail)
  WHERE id = p_keep_song_id;

  -- Move song_ratings: skip if a rating already exists for same user+instrument on keeper
  WITH moved AS (
    UPDATE song_ratings SET song_id = p_keep_song_id
    WHERE song_id = p_delete_song_id
      AND NOT EXISTS (
        SELECT 1 FROM song_ratings sr2
        WHERE sr2.song_id = p_keep_song_id
          AND sr2.user_id = song_ratings.user_id
          AND sr2.instrument_id = song_ratings.instrument_id
      )
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_ratings_moved FROM moved;

  -- Delete remaining ratings that couldn't be moved (duplicate user+instrument)
  DELETE FROM song_ratings WHERE song_id = p_delete_song_id;

  -- Move student_songs: skip if already tracking same song+user+instrument on keeper
  -- But first, if a student has the deleted song as "mastered" and the kept song as "learning",
  -- upgrade the kept record to "mastered" so no progress is lost.
  UPDATE student_songs keep_ss
  SET status = 'mastered',
      date_completed = COALESCE(keep_ss.date_completed, del_ss.date_completed)
  FROM student_songs del_ss
  WHERE keep_ss.song_id = p_keep_song_id
    AND del_ss.song_id = p_delete_song_id
    AND keep_ss.user_id = del_ss.user_id
    AND keep_ss.instrument_id = del_ss.instrument_id
    AND del_ss.status = 'mastered'
    AND keep_ss.status = 'learning';

  WITH moved AS (
    UPDATE student_songs SET song_id = p_keep_song_id
    WHERE song_id = p_delete_song_id
      AND NOT EXISTS (
        SELECT 1 FROM student_songs ss2
        WHERE ss2.song_id = p_keep_song_id
          AND ss2.user_id = student_songs.user_id
          AND ss2.instrument_id = student_songs.instrument_id
      )
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_student_songs_moved FROM moved;

  -- Delete remaining student_songs that couldn't be moved
  DELETE FROM student_songs WHERE song_id = p_delete_song_id;

  -- Move song_tutorials: skip if same URL already exists on keeper
  WITH moved AS (
    UPDATE song_tutorials SET song_id = p_keep_song_id
    WHERE song_id = p_delete_song_id
      AND NOT EXISTS (
        SELECT 1 FROM song_tutorials st2
        WHERE st2.song_id = p_keep_song_id
          AND st2.url = song_tutorials.url
      )
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_tutorials_moved FROM moved;

  -- Delete remaining tutorials that couldn't be moved
  DELETE FROM song_tutorials WHERE song_id = p_delete_song_id;

  -- Move student_resources: skip if same user+title already exists on keeper
  WITH moved AS (
    UPDATE student_resources SET song_id = p_keep_song_id
    WHERE song_id = p_delete_song_id
      AND NOT EXISTS (
        SELECT 1 FROM student_resources sr2
        WHERE sr2.song_id = p_keep_song_id
          AND sr2.user_id = student_resources.user_id
          AND sr2.title = student_resources.title
      )
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_resources_moved FROM moved;

  -- Delete remaining resources that couldn't be moved
  DELETE FROM student_resources WHERE song_id = p_delete_song_id;

  -- Move pending_links: skip if same link_type+url already exists on keeper
  WITH moved AS (
    UPDATE pending_links SET song_id = p_keep_song_id
    WHERE song_id = p_delete_song_id
      AND NOT EXISTS (
        SELECT 1 FROM pending_links pl2
        WHERE pl2.song_id = p_keep_song_id
          AND pl2.link_type = pending_links.link_type
          AND pl2.url = pending_links.url
      )
    RETURNING 1
  )
  SELECT COUNT(*) INTO v_pending_links_moved FROM moved;

  -- Delete remaining pending links that couldn't be moved
  DELETE FROM pending_links WHERE song_id = p_delete_song_id;

  -- Delete any resource_ratings referencing the deleted song
  DELETE FROM resource_ratings WHERE song_id = p_delete_song_id;

  -- Now safe to delete the duplicate song
  DELETE FROM songs WHERE id = p_delete_song_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', format('Merged "%s" into "%s"', v_delete_song.title, v_keep_song.title),
    'ratings_moved', v_ratings_moved,
    'student_songs_moved', v_student_songs_moved,
    'tutorials_moved', v_tutorials_moved,
    'resources_moved', v_resources_moved,
    'pending_links_moved', v_pending_links_moved
  );
END;
$$;

GRANT EXECUTE ON FUNCTION merge_songs(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION merge_songs IS 'Merges two songs by reassigning all related data (ratings, student progress, tutorials, resources, pending links) from the source song to the target song, then deletes the source song.';
