-- ============================================================
-- MIGRATION 175: Add get_song_learner_count RPC
--
-- Returns the platform-wide count of students currently learning
-- a specific song (status = 'learning' in student_songs).
--
-- Uses SET LOCAL row_security = off (same approach as
-- get_trending_songs migration 131) so the aggregate spans all
-- schools — no student-identifying data is returned.
--
-- Used by the song detail modal to show "+ N others also learning
-- this song" based on actual student_songs rows, replacing the
-- previous approach which incorrectly counted song_ratings rows.
-- ============================================================

CREATE OR REPLACE FUNCTION get_song_learner_count(p_song_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  v_count BIGINT;
BEGIN
  SET LOCAL row_security = off;
  SELECT COUNT(*)::BIGINT INTO v_count
  FROM student_songs
  WHERE song_id    = p_song_id
    AND status     = 'learning'
    AND deleted_at IS NULL;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION get_song_learner_count(UUID) TO authenticated;
