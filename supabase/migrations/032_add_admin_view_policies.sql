-- Migration: Add admin view policies for songs and classes
-- This allows admins to view all songs and classes for the admin dashboard stats
-- Uses SECURITY DEFINER function to avoid RLS recursion

-- Create a SECURITY DEFINER function to check admin status without triggering RLS
CREATE OR REPLACE FUNCTION is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid() AND role = 'admin'
  )
$$;

-- Drop existing policies if they exist (in case migration is re-run)
DROP POLICY IF EXISTS "Admins can view all songs" ON songs;
DROP POLICY IF EXISTS "Admins can view all classes" ON classes;

-- Allow admins to view all songs (including unapproved)
CREATE POLICY "Admins can view all songs" ON songs FOR SELECT USING (is_admin());

-- Allow admins to view all classes
CREATE POLICY "Admins can view all classes" ON classes FOR SELECT USING (is_admin());
