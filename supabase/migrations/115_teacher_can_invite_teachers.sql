-- Allow teachers to pre-register other teacher accounts
-- Admins retain full access; teachers can now also invite colleagues

-- Drop admin-only policies
DROP POLICY IF EXISTS "Admins can view pre-registered accounts" ON pre_registered_accounts;
DROP POLICY IF EXISTS "Admins can insert pre-registered accounts" ON pre_registered_accounts;
DROP POLICY IF EXISTS "Admins can delete pre-registered accounts" ON pre_registered_accounts;

-- Recreate policies for teachers and admins
CREATE POLICY "Teachers and admins can view pre-registered accounts"
ON pre_registered_accounts FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);

CREATE POLICY "Teachers and admins can insert pre-registered accounts"
ON pre_registered_accounts FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);

CREATE POLICY "Teachers and admins can delete pre-registered accounts"
ON pre_registered_accounts FOR DELETE USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('teacher', 'admin'))
);
