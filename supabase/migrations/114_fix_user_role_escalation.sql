-- Prevent authenticated users from changing their own role via the UPDATE policy.
-- Previously, with_check was absent so Postgres reused the USING expression
-- (auth.uid() = id), which only verified row ownership — not that the role
-- column was left unchanged. A student could self-promote to teacher/admin.
ALTER POLICY "Users can update their own data" ON users
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    AND role = (SELECT role FROM users WHERE id = auth.uid())
  );
