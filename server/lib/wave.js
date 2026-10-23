import { createHmac, timingSafeEqual } from 'node:crypto';

const WAVE_API = 'https://api.wave.com/v1';

/**
 * Crée une session de paiement Wave Checkout et renvoie { id, wave_launch_url }.
 * Doc : https://docs.wave.com/checkout
 */
export async function createCheckoutSession({ apiKey, amount, clientReference, successUrl, errorUrl }) {
  const response = await fetch(`${WAVE_API}/checkout/sessions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      // Un même paiement ne crée jamais deux sessions, même si l'appel est rejoué.
      'Idempotency-Key': clientReference,
    },
    body: JSON.stringify({
      amount: String(amount),
      currency: 'XOF',
      client_reference: clientReference,
      success_url: successUrl,
      error_url: errorUrl,
    }),
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`Wave ${response.status} : ${body.message ?? JSON.stringify(body)}`);
  }
  return body;
}

/**
 * Vérifie l'en-tête Wave-Signature (« t=<horodatage>,v1=<hmac>[,v1=...] ») :
 * HMAC-SHA256 de horodatage + corps brut, avec le secret du webhook.
 * Refuse les messages de plus de 5 minutes (rejeu).
 */
export function verifyWaveSignature({ header, rawBody, secret, now = Date.now(), toleranceSec = 300 }) {
  if (!header || !secret) return false;
  const parts = header.split(',').map((p) => p.trim().split('='));
  const timestamp = parts.find(([k]) => k === 't')?.[1];
  const signatures = parts.filter(([k]) => k === 'v1').map(([, v]) => v);
  if (!timestamp || signatures.length === 0) return false;
  if (Math.abs(now / 1000 - Number(timestamp)) > toleranceSec) return false;

  const expected = createHmac('sha256', secret).update(timestamp + rawBody).digest();
  return signatures.some((sig) => {
    const given = Buffer.from(sig, 'hex');
    return given.length === expected.length && timingSafeEqual(given, expected);
  });
}
