-- Migration: Fix infinite recursion in users table admin policy
-- The existing "Admins can view all users" policy causes recursion because
-- it queries the users table, triggering RLS, which queries users again.
-- This migration updates it to use the is_admin() function created in 032.

-- Drop the problematic policy from migration 001
DROP POLICY IF EXISTS "Admins can view all users" ON users;

-- Recreate using the is_admin() function to avoid recursion
CREATE POLICY "Admins can view all users" ON users FOR SELECT USING (is_admin());
