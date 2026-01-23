-- Create pending_links table for link moderation
CREATE TABLE pending_links (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  song_id UUID REFERENCES songs(id) ON DELETE CASCADE NOT NULL,
  link_type TEXT NOT NULL CHECK (link_type IN ('youtube_url', 'chords_url', 'tutorial_url')),
  url TEXT NOT NULL,
  submitted_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  submitted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMP WITH TIME ZONE
);

-- Create index for faster queries
CREATE INDEX idx_pending_links_status ON pending_links(status);
CREATE INDEX idx_pending_links_song_id ON pending_links(song_id);

-- Clear all existing links from songs table
UPDATE songs SET youtube_url = NULL, chords_url = NULL, tutorial_url = NULL;

-- RLS policies for pending_links

-- Enable RLS
ALTER TABLE pending_links ENABLE ROW LEVEL SECURITY;

-- Students can submit links (INSERT only)
CREATE POLICY "Students can submit links for review" ON pending_links
  FOR INSERT
  WITH CHECK (
    auth.uid() = submitted_by_user_id
    AND EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role = 'student'
    )
  );

-- Students can view their own pending submissions
CREATE POLICY "Students can view their own pending links" ON pending_links
  FOR SELECT
  USING (
    submitted_by_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('teacher', 'admin')
    )
  );

-- Teachers can view all pending links
CREATE POLICY "Teachers can view all pending links" ON pending_links
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('teacher', 'admin')
    )
  );

-- Teachers can approve/reject links (UPDATE only)
CREATE POLICY "Teachers can review pending links" ON pending_links
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
      AND role IN ('teacher', 'admin')
    )
  );

-- Create function to approve a pending link
CREATE OR REPLACE FUNCTION approve_pending_link(
  pending_link_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_song_id UUID;
  v_link_type TEXT;
  v_url TEXT;
BEGIN
  -- Get the pending link details
  SELECT song_id, link_type, url
  INTO v_song_id, v_link_type, v_url
  FROM pending_links
  WHERE id = pending_link_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending link not found or already processed';
  END IF;

  -- Update the song with the approved link
  IF v_link_type = 'youtube_url' THEN
    UPDATE songs SET youtube_url = v_url WHERE id = v_song_id;
  ELSIF v_link_type = 'chords_url' THEN
    UPDATE songs SET chords_url = v_url WHERE id = v_song_id;
  ELSIF v_link_type = 'tutorial_url' THEN
    UPDATE songs SET tutorial_url = v_url WHERE id = v_song_id;
  END IF;

  -- Mark the pending link as approved
  UPDATE pending_links
  SET status = 'approved',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = pending_link_id;
END;
$$;

-- Create function to reject a pending link
CREATE OR REPLACE FUNCTION reject_pending_link(
  pending_link_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Mark the pending link as rejected
  UPDATE pending_links
  SET status = 'rejected',
      reviewed_by_user_id = auth.uid(),
      reviewed_at = NOW()
  WHERE id = pending_link_id AND status = 'pending';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending link not found or already processed';
  END IF;
END;
$$;
