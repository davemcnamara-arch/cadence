-- Migration: Add admin view policies for songs and classes
-- This allows admins to view all songs and classes for the admin dashboard stats

-- Allow admins to view all songs (including unapproved)
CREATE POLICY "Admins can view all songs" ON songs FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

-- Allow admins to view all classes
CREATE POLICY "Admins can view all classes" ON classes FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);
