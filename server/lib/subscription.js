// Règles d'abonnement, sans accès à la base : testées dans test/subscription.test.js.

export const TRIAL_DAYS = 30;

export const PLANS = {
  monthly: { amount: 1000, months: 1, label: 'Mensuel' },
  yearly: { amount: 10000, months: 12, label: 'Annuel' },
};

const DEVICE_ID = /^[A-Za-z0-9_-]{8,128}$/;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const isValidDeviceId = (id) => typeof id === 'string' && DEVICE_ID.test(id);
export const isUuid = (id) => typeof id === 'string' && UUID.test(id);

/**
 * État d'accès au direct d'un appareil (ligne de la table devices).
 * L'abonnement payé prime sur l'essai ; sans l'un ni l'autre, l'accès est coupé.
 */
export function accessStatus(device, now = new Date()) {
  const trialEndsAt = new Date(device.trial_ends_at);
  const paidUntil = device.paid_until ? new Date(device.paid_until) : null;

  let status = 'expired';
  let accessUntil = null;
  if (paidUntil && paidUntil > now) {
    status = 'active';
    accessUntil = paidUntil;
  } else if (trialEndsAt > now) {
    status = 'trial';
    accessUntil = trialEndsAt;
  }

  return {
    status,
    trialEndsAt: trialEndsAt.toISOString(),
    paidUntil: paidUntil?.toISOString() ?? null,
    accessUntil: accessUntil?.toISOString() ?? null,
    serverTime: now.toISOString(),
  };
}
