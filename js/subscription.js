// ============================================================
// subscription.js – reusable subscription-status helper
//
// Call checkSubscriptionStatus(auth) on every teacher page load
// to determine whether the teacher's subscription is active.
//
// NOTE: This helper is intentionally called for teachers only.
// Students are NOT gated by subscription status — they retain
// full read/write access regardless of whether their school's
// subscription has lapsed.  See onUserSignedIn() in app.js.
// ============================================================

/**
 * Check the current user's subscription status.
 *
 * @param {object} auth - The app's AuthManager instance (from auth.js).
 * @returns {Promise<{
 *   hasSubscription: boolean,
 *   isActive: boolean,
 *   isExpired: boolean,
 *   status: string|null,
 *   currentPeriodEnd: Date|null,
 *   sub: object|null
 * }>}
 *
 * Callers should treat the subscription as lapsed when either:
 *   - hasSubscription is false (never subscribed / subscription deleted), OR
 *   - isActive is false (status is not active/trialing, or period has ended)
 */
export async function checkSubscriptionStatus(auth) {
  let sub = null;

  try {
    const { data } = await auth.rpcDirect('get_my_subscription', {});
    sub = data || null;
  } catch (e) {
    console.warn('checkSubscriptionStatus: RPC failed', e.message);
  }

  if (!sub) {
    return {
      hasSubscription: false,
      isActive: false,
      isExpired: false,
      status: null,
      currentPeriodEnd: null,
      sub: null,
    };
  }

  const statusActive = sub.status === 'active' || sub.status === 'trialing';
  const periodEnd = sub.current_period_end ? new Date(sub.current_period_end) : null;
  const periodValid = periodEnd ? periodEnd > new Date() : true;
  const isActive = statusActive && periodValid;

  return {
    hasSubscription: true,
    isActive,
    isExpired: !isActive,
    status: sub.status,
    currentPeriodEnd: periodEnd,
    sub,
  };
}
