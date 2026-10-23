import { sql, touchDevice } from '../lib/db.js';
import { json, publicUrl, readJson } from '../lib/http.js';
import { PLANS, isValidDeviceId } from '../lib/subscription.js';
import { createCheckoutSession } from '../lib/wave.js';

// POST /api/checkout { deviceId, plan } → { launchUrl } à ouvrir dans Wave.
export async function POST(request) {
  const body = await readJson(request);
  const plan = PLANS[body?.plan];
  if (!isValidDeviceId(body?.deviceId) || !plan) {
    return json({ error: 'deviceId ou plan invalide' }, 400);
  }

  await touchDevice(body.deviceId, null);
  const [payment] = await sql`
    insert into payments (device_id, plan, amount)
    values (${body.deviceId}, ${body.plan}, ${plan.amount})
    returning id`;

  const base = publicUrl(request);
  let session;
  try {
    session = await createCheckoutSession({
      apiKey: process.env.WAVE_API_KEY,
      amount: plan.amount,
      clientReference: payment.id,
      successUrl: `${base}/api/paiement?statut=ok`,
      errorUrl: `${base}/api/paiement?statut=erreur`,
    });
  } catch (error) {
    console.error(error);
    await sql`update payments set status = 'failed' where id = ${payment.id}`;
    return json({ error: 'Wave indisponible, réessayez.' }, 502);
  }

  await sql`update payments set wave_session_id = ${session.id} where id = ${payment.id}`;
  return json({ paymentId: payment.id, launchUrl: session.wave_launch_url });
}
