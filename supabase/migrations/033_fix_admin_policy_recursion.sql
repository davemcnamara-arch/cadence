-- Migration: Fix infinite recursion in admin policies
-- Several policies use subqueries that query the users table, causing recursion.
-- This migration updates them to use the is_admin() function created in 032.

-- Fix users table policy
DROP POLICY IF EXISTS "Admins can view all users" ON users;
CREATE POLICY "Admins can view all users" ON users FOR SELECT USING (is_admin());

-- Fix levels table policy
DROP POLICY IF EXISTS "Only admins can modify levels" ON levels;
CREATE POLICY "Only admins can modify levels" ON levels FOR ALL USING (is_admin());

-- Fix instruments table policy
DROP POLICY IF EXISTS "Only admins can modify instruments" ON instruments;
CREATE POLICY "Only admins can modify instruments" ON instruments FOR ALL USING (is_admin());
