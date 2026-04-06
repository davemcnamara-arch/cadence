import Stripe from 'stripe';

const PRICES = {
  individual: {
    unit_amount: 4900,   // A$49.00
    nickname: 'Individual Teacher – Annual',
    description: 'A$49 billed annually – one teacher, up to 15 students',
  },
  school: {
    unit_amount: 19900,  // A$199.00
    nickname: 'School License – Annual',
    description: 'A$199 billed annually – unlimited teachers and students',
  },
};

const UUID_V4_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Origin/Host validation — lightweight CSRF defence for same-origin SPA.
  // Browsers always send Origin on cross-origin requests; if it's present and
  // doesn't match our host we reject the request.
  const requestOrigin = req.headers.origin;
  if (requestOrigin) {
    const host = req.headers.host;
    const allowedOrigins = new Set([
      `https://${host}`,
      `http://${host}`,
    ]);
    if (!allowedOrigins.has(requestOrigin)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
  }

  const { plan, supabase_uid } = req.body ?? {};

  if (!plan || !PRICES[plan]) {
    return res.status(400).json({ error: 'Invalid plan. Must be "individual" or "school".' });
  }

  // supabase_uid is legitimately null for unauthenticated checkouts, but if
  // provided it must be a valid UUID v4.
  if (supabase_uid != null && !UUID_V4_RE.test(supabase_uid)) {
    return res.status(400).json({ error: 'Invalid supabase_uid format.' });
  }

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, { apiVersion: '2024-04-10' });

  const origin = req.headers.origin || `https://${req.headers.host}`;

  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    payment_method_types: ['card'],
    line_items: [
      {
        price_data: {
          currency: 'aud',
          recurring: { interval: 'year' },
          product_data: { name: PRICES[plan].nickname, description: PRICES[plan].description },
          unit_amount: PRICES[plan].unit_amount,
        },
        quantity: 1,
      },
    ],
    custom_text: {
      submit: { message: 'You will be charged the full annual amount today.' },
    },
    metadata: {
      plan_type: plan,
      supabase_uid: supabase_uid || '',
    },
    success_url: `${origin}/subscribe-success.html?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${origin}/subscribe.html`,
  });

  return res.status(200).json({ url: session.url });
}
