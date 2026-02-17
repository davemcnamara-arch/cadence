-- Restrict teacher account creation (pre_registered_accounts) to admins only
-- Previously teachers could also create teacher accounts; now only admins can.

-- Drop existing permissive policies
DROP POLICY IF EXISTS "Teachers and admins can view pre-registered accounts" ON pre_registered_accounts;
DROP POLICY IF EXISTS "Teachers and admins can insert pre-registered accounts" ON pre_registered_accounts;
DROP POLICY IF EXISTS "Teachers and admins can delete pre-registered accounts" ON pre_registered_accounts;

-- Recreate policies as admin-only
CREATE POLICY "Admins can view pre-registered accounts"
ON pre_registered_accounts FOR SELECT USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Admins can insert pre-registered accounts"
ON pre_registered_accounts FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Admins can delete pre-registered accounts"
ON pre_registered_accounts FOR DELETE USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);
