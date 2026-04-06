-- Table to track processed Stripe webhook events for idempotency
CREATE TABLE processed_webhook_events (
  event_id     TEXT PRIMARY KEY,
  processed_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE processed_webhook_events ENABLE ROW LEVEL SECURITY;

-- Only the service role can read/write this table (no anon or authenticated access)
CREATE POLICY "service role only"
  ON processed_webhook_events
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);
