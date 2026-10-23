import { sql, touchDevice } from '../lib/db.js';
import { json, readJson } from '../lib/http.js';
import {
  PLANS,
  isValidDeviceId,
  normalizeSenegalPhone,
  wavePaymentUrl,
} from '../lib/subscription.js';

const MAX_PENDING = 3;

// POST /api/payment-claim { deviceId, plan, payerPhone } → { payUrl }
// Enregistre « je vais payer avec ce numéro Wave » ; un admin valide ensuite le
// paiement après l'avoir retrouvé dans Wave Business.
export async function POST(request) {
  const body = await readJson(request);
  const plan = PLANS[body?.plan];
  const phone = normalizeSenegalPhone(body?.payerPhone);
  if (!isValidDeviceId(body?.deviceId) || !plan) {
    return json({ error: 'Demande invalide.' }, 400);
  }
  if (!phone) {
    return json({ error: 'Numéro Wave invalide (ex. : 77 123 45 67).' }, 400);
  }

  await touchDevice(body.deviceId, null);
  // Évite qu'un appareil remplisse la file de validation.
  const [{ pending }] = await sql`
    select count(*)::int as pending from payments
     where device_id = ${body.deviceId} and status = 'pending'
       and created_at > now() - interval '1 day'`;
  if (pending >= MAX_PENDING) {
    return json(
      { error: 'Vous avez déjà des paiements en attente de vérification. Patientez un peu.' },
      429,
    );
  }

  const [payment] = await sql`
    insert into payments (device_id, plan, amount, method, payer_phone)
    values (${body.deviceId}, ${body.plan}, ${plan.amount}, 'wave_link', ${phone})
    returning id`;
  return json({ paymentId: payment.id, payUrl: wavePaymentUrl(plan.amount) });
}
