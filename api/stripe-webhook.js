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
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).json({ error: `Webhook error: ${err.message}` });
  }

  if (event.type === 'checkout.session.completed') {
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
      console.error('Could not retrieve subscription details:', err.message);
    }

    // Use the Supabase service-role client to bypass RLS
    const supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_ROLE_KEY
    );

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
      console.error('Supabase upsert error:', upsertError);
      return res.status(500).json({ error: 'Database error' });
    }

    // If school plan, create a school record linked to this subscription
    if (plan_type === 'school' && supabase_uid) {
      const { data: existingSchool } = await supabase
        .from('schools')
        .select('id')
        .eq('owner_id', supabase_uid)
        .maybeSingle();

      if (!existingSchool) {
        const { error: schoolError } = await supabase
          .from('schools')
          .insert({ owner_id: supabase_uid, name: 'My School' });

        if (schoolError) {
          console.error('School creation error:', schoolError);
          // Non-fatal: subscription row already written
        }
      }
    }
  }

  return res.status(200).json({ received: true });
}
