-- Soft-delete original seed songs that no student has ever engaged with.
-- Seed songs are identified by added_by_user_id IS NULL (system-inserted, not student-submitted).
-- Songs are kept if any student has a student_songs row for them, regardless of status.

UPDATE songs
SET deleted_at = NOW()
WHERE added_by_user_id IS NULL
  AND deleted_at IS NULL
  AND id NOT IN (SELECT DISTINCT song_id FROM student_songs);
