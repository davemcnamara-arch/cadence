-- Cadence Music Tracker - Initial Database Schema

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table (extends Supabase auth.users)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  google_id TEXT UNIQUE,
  role TEXT NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher', 'admin')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Instruments table
CREATE TABLE instruments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  icon TEXT NOT NULL,
  description TEXT,
  display_order INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Levels table
CREATE TABLE levels (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  instrument_id UUID NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
  level_number INTEGER NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  skills_json JSONB NOT NULL DEFAULT '[]',
  grading_checklist_json JSONB NOT NULL DEFAULT '[]',
  example_songs TEXT[],
  is_branch BOOLEAN DEFAULT FALSE,
  branch_name TEXT,
  parent_level_id UUID REFERENCES levels(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(instrument_id, level_number, branch_name)
);

-- Student progress table
CREATE TABLE student_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  instrument_id UUID NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
  current_level INTEGER NOT NULL DEFAULT 1,
  current_branch TEXT,
  date_started TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, instrument_id)
);

-- Songs table
CREATE TABLE songs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  youtube_url TEXT,
  spotify_url TEXT,
  thumbnail TEXT,
  duration INTEGER,
  date_added TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  added_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  approved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Song ratings table
CREATE TABLE song_ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  instrument_id UUID NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
  assessed_level INTEGER NOT NULL,
  branch_name TEXT,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  checklist_responses_json JSONB NOT NULL DEFAULT '{}',
  date_graded TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(song_id, instrument_id, user_id)
);

-- Student songs table (tracking learning/mastered status)
CREATE TABLE student_songs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  song_id UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  instrument_id UUID NOT NULL REFERENCES instruments(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('learning', 'mastered')),
  date_started TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  date_completed TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  UNIQUE(user_id, song_id, instrument_id)
);

-- Classes table
CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  teacher_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  year_level TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  archived BOOLEAN DEFAULT FALSE
);

-- Class members table
CREATE TABLE class_members (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(class_id, user_id)
);

-- Create indexes for performance
CREATE INDEX idx_student_progress_user ON student_progress(user_id);
CREATE INDEX idx_student_progress_instrument ON student_progress(instrument_id);
CREATE INDEX idx_songs_title ON songs(title);
CREATE INDEX idx_songs_artist ON songs(artist);
CREATE INDEX idx_songs_approved ON songs(approved);
CREATE INDEX idx_song_ratings_song ON song_ratings(song_id);
CREATE INDEX idx_song_ratings_instrument ON song_ratings(instrument_id);
CREATE INDEX idx_song_ratings_level ON song_ratings(assessed_level);
CREATE INDEX idx_student_songs_user ON student_songs(user_id);
CREATE INDEX idx_student_songs_status ON student_songs(status);
CREATE INDEX idx_class_members_class ON class_members(class_id);
CREATE INDEX idx_class_members_user ON class_members(user_id);
CREATE INDEX idx_levels_instrument ON levels(instrument_id, level_number);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE instruments ENABLE ROW LEVEL SECURITY;
ALTER TABLE levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE song_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_songs ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_members ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users
CREATE POLICY "Users can view their own data" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own data" ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Teachers can view students in their classes" ON users FOR SELECT USING (
  role = 'student' AND id IN (
    SELECT cm.user_id FROM class_members cm
    JOIN classes c ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);
CREATE POLICY "Admins can view all users" ON users FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

-- RLS Policies for instruments (public read)
CREATE POLICY "Anyone can view instruments" ON instruments FOR SELECT USING (true);
CREATE POLICY "Only admins can modify instruments" ON instruments FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

-- RLS Policies for levels (public read)
CREATE POLICY "Anyone can view levels" ON levels FOR SELECT USING (true);
CREATE POLICY "Only admins can modify levels" ON levels FOR ALL USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

-- RLS Policies for student_progress
CREATE POLICY "Students can view own progress" ON student_progress FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Students can insert own progress" ON student_progress FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Students can update own progress" ON student_progress FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Teachers can view class progress" ON student_progress FOR SELECT USING (
  user_id IN (
    SELECT cm.user_id FROM class_members cm
    JOIN classes c ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

-- RLS Policies for songs
CREATE POLICY "Anyone can view approved songs" ON songs FOR SELECT USING (approved = true);
CREATE POLICY "Users can view their own submissions" ON songs FOR SELECT USING (added_by_user_id = auth.uid());
CREATE POLICY "Users can add songs" ON songs FOR INSERT WITH CHECK (added_by_user_id = auth.uid());
CREATE POLICY "Teachers can approve songs" ON songs FOR UPDATE USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);
CREATE POLICY "Admins can delete songs" ON songs FOR DELETE USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

-- RLS Policies for song_ratings
CREATE POLICY "Users can view all ratings" ON song_ratings FOR SELECT USING (true);
CREATE POLICY "Users can add their own ratings" ON song_ratings FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update their own ratings" ON song_ratings FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete their own ratings" ON song_ratings FOR DELETE USING (user_id = auth.uid());

-- RLS Policies for student_songs
CREATE POLICY "Students can view own songs" ON student_songs FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Students can add own songs" ON student_songs FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Students can update own songs" ON student_songs FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Students can delete own songs" ON student_songs FOR DELETE USING (user_id = auth.uid());
CREATE POLICY "Classmates can see what others are learning" ON student_songs FOR SELECT USING (
  user_id IN (
    SELECT cm2.user_id FROM class_members cm1
    JOIN class_members cm2 ON cm1.class_id = cm2.class_id
    WHERE cm1.user_id = auth.uid()
  )
);
CREATE POLICY "Teachers can view class songs" ON student_songs FOR SELECT USING (
  user_id IN (
    SELECT cm.user_id FROM class_members cm
    JOIN classes c ON c.id = cm.class_id
    WHERE c.teacher_id = auth.uid()
  )
);

-- RLS Policies for classes
CREATE POLICY "Teachers can view own classes" ON classes FOR SELECT USING (teacher_id = auth.uid());
CREATE POLICY "Teachers can create classes" ON classes FOR INSERT WITH CHECK (teacher_id = auth.uid());
CREATE POLICY "Teachers can update own classes" ON classes FOR UPDATE USING (teacher_id = auth.uid());
CREATE POLICY "Students can view their classes" ON classes FOR SELECT USING (
  id IN (SELECT class_id FROM class_members WHERE user_id = auth.uid())
);

-- RLS Policies for class_members
CREATE POLICY "Class members can view classmates" ON class_members FOR SELECT USING (
  class_id IN (SELECT class_id FROM class_members WHERE user_id = auth.uid())
);
CREATE POLICY "Teachers can manage class members" ON class_members FOR ALL USING (
  class_id IN (SELECT id FROM classes WHERE teacher_id = auth.uid())
);
CREATE POLICY "Students can join classes" ON class_members FOR INSERT WITH CHECK (user_id = auth.uid());

-- Functions and triggers
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_levels_updated_at BEFORE UPDATE ON levels
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_student_progress_updated_at BEFORE UPDATE ON student_progress
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Function to generate unique class codes
CREATE OR REPLACE FUNCTION generate_class_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result TEXT := '';
  i INTEGER;
BEGIN
  FOR i IN 1..6 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;
