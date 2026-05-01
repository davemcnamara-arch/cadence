-- Collaborative filtering: "students who mastered the same song then chose these songs".
-- For a given student + instrument, finds songs they have mastered, then aggregates what
-- other students started learning after mastering those same songs. Returns ranked results
-- excluding songs the current student already has, filtered to a minimum student count to
-- suppress sparse data.

CREATE OR REPLACE FUNCTION get_next_song_suggestions(
  p_user_id       UUID,
  p_instrument_id UUID,
  p_limit         INT DEFAULT 10,
  p_min_count     INT DEFAULT 2
)
RETURNS TABLE (
  song_id       UUID,
  title         TEXT,
  artist        TEXT,
  student_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  RETURN QUERY
  SELECT
    s.id                  AS song_id,
    s.title               AS title,
    s.artist              AS artist,
    COUNT(DISTINCT ss_next.user_id)::BIGINT AS student_count
  FROM student_songs ss_mastered
  -- Other students who also mastered the same song on the same instrument
  JOIN student_songs ss_peer
    ON  ss_peer.song_id        = ss_mastered.song_id
    AND ss_peer.instrument_id  = ss_mastered.instrument_id
    AND ss_peer.user_id       <> p_user_id
    AND ss_peer.status         = 'mastered'
    AND ss_peer.deleted_at     IS NULL
  -- Songs those peers started learning after mastering the matched song
  JOIN student_songs ss_next
    ON  ss_next.user_id        = ss_peer.user_id
    AND ss_next.instrument_id  = p_instrument_id
    AND ss_next.date_started   > ss_peer.date_completed
    AND ss_next.deleted_at     IS NULL
  JOIN songs s
    ON  s.id               = ss_next.song_id
    AND s.deleted_at       IS NULL
  WHERE ss_mastered.user_id       = p_user_id
    AND ss_mastered.instrument_id = p_instrument_id
    AND ss_mastered.status        = 'mastered'
    AND ss_mastered.deleted_at    IS NULL
    -- Exclude songs the current student already has
    AND NOT EXISTS (
      SELECT 1
      FROM student_songs ss_own
      WHERE ss_own.user_id       = p_user_id
        AND ss_own.song_id       = ss_next.song_id
        AND ss_own.instrument_id = p_instrument_id
        AND ss_own.deleted_at    IS NULL
    )
  GROUP BY s.id, s.title, s.artist
  HAVING COUNT(DISTINCT ss_next.user_id) >= p_min_count
  ORDER BY student_count DESC
  LIMIT p_limit;
END;
$$;

GRANT EXECUTE ON FUNCTION get_next_song_suggestions(UUID, UUID, INT, INT) TO authenticated;
