import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';

// Vercel does not parse the raw body for webhook routes; we need the raw bytes
// to verify the Stripe signature. Tell Vercel to skip body parsing.
export const config = { api: { bodyParser: false } };

function getRawBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, { apiVersion: '2024-04-10' });
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  let event;
  try {
    const rawBody = await getRawBody(req);
    const signature = req.headers['stripe-signature'];
    event = stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed');
    return res.status(400).json({ error: `Webhook error: ${err.message}` });
  }

  // Use the Supabase service-role client to bypass RLS for all handlers below
  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY
  );

  // ---------------------------------------------------------------
  // Helper: restore a teacher's school (clear archived_at).
  // Called on any event that makes a subscription active again.
  // All school data is preserved during archive; this simply
  // un-hides it.
  // ---------------------------------------------------------------
  async function restoreSchoolAccess(teacherId, schoolId) {
    if (teacherId) {
      await supabase.rpc('restore_school_for_teacher', { p_teacher_id: teacherId });
    }
    if (schoolId) {
      await supabase.rpc('restore_school_by_id', { p_school_id: schoolId });
    }
  }

  // ---------------------------------------------------------------
  // Helper: archive a teacher's school (set archived_at = NOW()).
  // Students retain full read/write access regardless of archived_at.
  // ---------------------------------------------------------------
  async function archiveSchoolAccess(teacherId) {
    if (teacherId) {
      await supabase.rpc('archive_school_for_teacher', { p_teacher_id: teacherId });
    }
  }

  // ---------------------------------------------------------------
  // EVENT: checkout.session.completed
  // New purchase or renewal via Stripe Checkout.
  // ---------------------------------------------------------------
  if (event.type === 'checkout.session.completed') {
    // Idempotency check: skip if this event has already been processed
    const { data: existingEvent } = await supabase
      .from('processed_webhook_events')
      .select('event_id')
      .eq('event_id', event.id)
      .maybeSingle();

    if (existingEvent) {
      console.log(`Duplicate webhook event ${event.id} — skipping`);
      return res.status(200).json({ received: true });
    }

    const session = event.data.object;

    const supabase_uid = session.metadata?.supabase_uid || null;
    const plan_type = session.metadata?.plan_type;
    const stripe_customer_id = session.customer;
    const stripe_subscription_id = session.subscription;

    // Retrieve the full subscription object to get period dates
    let periodStart = new Date();
    let periodEnd = new Date();
    periodEnd.setFullYear(periodEnd.getFullYear() + 1);

    try {
      const subscription = await stripe.subscriptions.retrieve(stripe_subscription_id);
      periodStart = new Date(subscription.current_period_start * 1000);
      periodEnd = new Date(subscription.current_period_end * 1000);
    } catch (err) {
      console.error('Could not retrieve subscription details');
    }

    // Upsert the subscription row keyed on stripe_subscription_id
    const { error: upsertError } = await supabase
      .from('subscriptions')
      .upsert(
        {
          teacher_id: supabase_uid || null,
          plan_type,
          status: 'active',
          stripe_subscription_id,
          stripe_customer_id,
          current_period_start: periodStart.toISOString(),
          current_period_end: periodEnd.toISOString(),
        },
        { onConflict: 'stripe_subscription_id' }
      );

    if (upsertError) {
      console.error('Supabase upsert error', upsertError?.code ?? 'unknown');
      return res.status(500).json({ error: 'Database error' });
    }

    // Record the event as processed so replays are no-ops
    const { error: idempotencyError } = await supabase
      .from('processed_webhook_events')
      .insert({ event_id: event.id });

    if (idempotencyError) {
      console.error('Failed to record processed webhook event', idempotencyError?.code ?? 'unknown');
      // Non-fatal: subscription already written; log and continue
    }

    // Restore school access in case the teacher is resubscribing after a lapse
    await restoreSchoolAccess(supabase_uid, null);

    // If school plan, create a school record linked to this subscription
    if (plan_type === 'school' && supabase_uid) {
      const { data: existingSchool } = await supabase
        .from('schools')
        .select('id')
        .eq('created_by', supabase_uid)
        .maybeSingle();

      if (!existingSchool) {
        const { error: schoolError } = await supabase
          .from('schools')
          .insert({ created_by: supabase_uid, name: 'My School' });

        if (schoolError) {
          console.error('School creation error', schoolError?.code ?? 'unknown');
          // Non-fatal: subscription row already written
        }
      }
    }
  }

  // ---------------------------------------------------------------
  // EVENT: customer.subscription.updated
  // Stripe fires this when renewal succeeds, plan changes, or the
  // subscription is cancelled/expired.
  // ---------------------------------------------------------------
  if (event.type === 'customer.subscription.updated') {
    const stripeSub = event.data.object;
    const stripe_subscription_id = stripeSub.id;
    const newStatus = stripeSub.status; // e.g. 'active', 'canceled', 'past_due'

    // Map Stripe status → our internal status values
    const internalStatus = (() => {
      if (newStatus === 'active' || newStatus === 'trialing') return newStatus;
      if (newStatus === 'canceled' || newStatus === 'incomplete_expired') return 'cancelled';
      return 'expired'; // past_due, unpaid, incomplete, paused
    })();

    const periodStart = new Date(stripeSub.current_period_start * 1000);
    const periodEnd   = new Date(stripeSub.current_period_end   * 1000);

    // Update the subscription row
    const { data: updatedRows, error: updateError } = await supabase
      .from('subscriptions')
      .update({
        status: internalStatus,
        current_period_start: periodStart.toISOString(),
        current_period_end:   periodEnd.toISOString(),
      })
      .eq('stripe_subscription_id', stripe_subscription_id)
      .select('teacher_id, school_id');

    if (updateError) {
      console.error('Supabase update error (subscription.updated)', updateError?.code ?? 'unknown');
      return res.status(500).json({ error: 'Database error' });
    }

    const row = updatedRows?.[0];
    if (row) {
      if (internalStatus === 'active' || internalStatus === 'trialing') {
        // Subscription renewed or reactivated — restore school access
        await restoreSchoolAccess(row.teacher_id, row.school_id);
      } else {
        // Subscription lapsed — archive the teacher's school.
        // All school data (classes, assignments, etc.) is preserved in the DB.
        // Students retain full read/write access regardless of archived_at.
        await archiveSchoolAccess(row.teacher_id);
      }
    }
  }

  // ---------------------------------------------------------------
  // EVENT: invoice.payment_succeeded
  // Fired when a renewal payment clears.  Ensures the subscription
  // is marked active and school access is restored even if a prior
  // lapse had archived it.
  // ---------------------------------------------------------------
  if (event.type === 'invoice.payment_succeeded') {
    const invoice = event.data.object;
    const stripe_subscription_id = invoice.subscription;
    if (!stripe_subscription_id) {
      return res.status(200).json({ received: true });
    }

    // Retrieve fresh subscription details from Stripe
    let stripeSub;
    try {
      stripeSub = await stripe.subscriptions.retrieve(stripe_subscription_id);
    } catch (err) {
      console.error('Could not retrieve subscription on invoice.payment_succeeded');
      return res.status(200).json({ received: true });
    }

    if (stripeSub.status !== 'active' && stripeSub.status !== 'trialing') {
      return res.status(200).json({ received: true });
    }

    const periodStart = new Date(stripeSub.current_period_start * 1000);
    const periodEnd   = new Date(stripeSub.current_period_end   * 1000);

    const { data: updatedRows, error: updateError } = await supabase
      .from('subscriptions')
      .update({
        status: stripeSub.status,
        current_period_start: periodStart.toISOString(),
        current_period_end:   periodEnd.toISOString(),
      })
      .eq('stripe_subscription_id', stripe_subscription_id)
      .select('teacher_id, school_id');

    if (updateError) {
      console.error('Supabase update error (invoice.payment_succeeded)', updateError?.code ?? 'unknown');
      return res.status(500).json({ error: 'Database error' });
    }

    const row = updatedRows?.[0];
    if (row) {
      await restoreSchoolAccess(row.teacher_id, row.school_id);
    }
  }

  return res.status(200).json({ received: true });
}
