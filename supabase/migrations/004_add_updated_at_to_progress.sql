-- Add missing updated_at column to student_progress table
-- This column is expected by the update_student_progress_updated_at trigger

ALTER TABLE student_progress
ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
