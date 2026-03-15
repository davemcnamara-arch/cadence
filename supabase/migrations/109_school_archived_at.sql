-- ============================================================
-- MIGRATION 109: Add archived_at to schools table
--
-- When a teacher's subscription lapses, their school is archived
-- (archived_at is set to NOW()).  On resubscribe the column is
-- cleared back to NULL, restoring full access.
--
-- All school data (classes, assignments, etc.) is preserved while
-- archived — only the teacher's dashboard is gated.  Students
-- retain full read/write access regardless of archived_at.
-- ============================================================

ALTER TABLE schools ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- Index to make "find active schools" queries fast
CREATE INDEX IF NOT EXISTS idx_schools_archived_at ON schools(archived_at) WHERE archived_at IS NULL;

-- ============================================================
-- RPC: archive_school_for_teacher(p_teacher_id UUID)
-- Sets archived_at = NOW() on every school the teacher owns or
-- administers.  Called by the Stripe webhook (service-role) when
-- a subscription lapses.
-- ============================================================
CREATE OR REPLACE FUNCTION archive_school_for_teacher(p_teacher_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Archive schools where this teacher is the admin/owner
  UPDATE schools
  SET archived_at = NOW()
  WHERE archived_at IS NULL
    AND id IN (
      SELECT school_id FROM school_members
      WHERE user_id = p_teacher_id
        AND school_role = 'admin'
    );
END;
$$;

-- ============================================================
-- RPC: restore_school_for_teacher(p_teacher_id UUID)
-- Clears archived_at on every school the teacher administers.
-- Called by the Stripe webhook on resubscribe / payment success.
-- ============================================================
CREATE OR REPLACE FUNCTION restore_school_for_teacher(p_teacher_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE schools
  SET archived_at = NULL
  WHERE archived_at IS NOT NULL
    AND id IN (
      SELECT school_id FROM school_members
      WHERE user_id = p_teacher_id
        AND school_role = 'admin'
    );
END;
$$;

-- ============================================================
-- RPC: restore_school_by_id(p_school_id UUID)
-- Clears archived_at on a school plan's school directly.
-- Called by the Stripe webhook on resubscribe for school plans.
-- ============================================================
CREATE OR REPLACE FUNCTION restore_school_by_id(p_school_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE schools SET archived_at = NULL WHERE id = p_school_id;
END;
$$;

-- Grant execute to service role (webhook uses service role key)
GRANT EXECUTE ON FUNCTION archive_school_for_teacher(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION restore_school_for_teacher(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION restore_school_by_id(UUID) TO service_role;
