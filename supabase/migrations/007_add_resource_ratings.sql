-- Create table for storing resource helpfulness ratings
CREATE TABLE resource_ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_song_id UUID NOT NULL REFERENCES student_songs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  chords_rating INTEGER CHECK (chords_rating >= 1 AND chords_rating <= 5),
  tutorial_rating INTEGER CHECK (tutorial_rating >= 1 AND tutorial_rating <= 5),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(student_song_id, user_id)
);

-- Add RLS policies
ALTER TABLE resource_ratings ENABLE ROW LEVEL SECURITY;

-- Users can read their own ratings
CREATE POLICY "Users can read own resource ratings"
  ON resource_ratings FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own ratings
CREATE POLICY "Users can insert own resource ratings"
  ON resource_ratings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own ratings
CREATE POLICY "Users can update own resource ratings"
  ON resource_ratings FOR UPDATE
  USING (auth.uid() = user_id);
