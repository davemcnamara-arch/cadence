import Stripe from 'stripe';

const PRICES = {
  individual: {
    unit_amount: 4900,   // $49.00
    nickname: 'Individual Teacher – Annual',
  },
  school: {
    unit_amount: 19900,  // $199.00
    nickname: 'School License – Annual',
  },
};

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { plan, supabase_uid } = req.body ?? {};

  if (!plan || !PRICES[plan]) {
    return res.status(400).json({ error: 'Invalid plan. Must be "individual" or "school".' });
  }

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, { apiVersion: '2024-04-10' });

  const origin = req.headers.origin || `https://${req.headers.host}`;

  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    payment_method_types: ['card'],
    line_items: [
      {
        price_data: {
          currency: 'usd',
          recurring: { interval: 'year' },
          product_data: { name: PRICES[plan].nickname },
          unit_amount: PRICES[plan].unit_amount,
        },
        quantity: 1,
      },
    ],
    metadata: {
      plan_type: plan,
      supabase_uid: supabase_uid || '',
    },
    success_url: `${origin}/subscribe-success.html?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${origin}/subscribe.html`,
  });

  return res.status(200).json({ url: session.url });
}
