import { sql } from '../lib/db.js';
import { json } from '../lib/http.js';
import { isUuid } from '../lib/subscription.js';
import { verifyWaveSignature } from '../lib/wave.js';

// POST /api/wave-webhook : Wave signale ici les paiements terminés.
// À déclarer dans Wave Business → Développeurs → Webhooks.
export async function POST(request) {
  const rawBody = await request.text();
  const valid = verifyWaveSignature({
    header: request.headers.get('wave-signature'),
    rawBody,
    secret: process.env.WAVE_WEBHOOK_SECRET,
  });
  if (!valid) return json({ error: 'signature invalide' }, 401);

  const event = JSON.parse(rawBody);
  const session = event.data ?? {};
  const paymentId = session.client_reference;
  if (!isUuid(paymentId)) return json({ ignored: true });

  const amount = Number(session.amount);
  if (
    event.type === 'checkout.session.completed' &&
    session.payment_status === 'succeeded' &&
    session.currency === 'XOF' &&
    Number.isInteger(amount)
  ) {
    // En une seule requête : le paiement passe à « réussi » une seule fois (Wave
    // peut renvoyer le même événement), le montant doit correspondre au plan, et
    // la période payée s'ajoute après l'essai ou l'abonnement en cours.
    const rows = await sql`
      with paid as (
        update payments
           set status = 'succeeded', paid_at = now(), wave_session_id = ${session.id}
         where id = ${paymentId}
           and status <> 'succeeded'
           and amount = ${amount}
        returning device_id, plan
      )
      update devices d
         set paid_until = greatest(now(), coalesce(d.paid_until, now()), d.trial_ends_at)
                          + make_interval(months => case paid.plan when 'yearly' then 12 else 1 end)
        from paid
       where d.device_id = paid.device_id
      returning d.device_id, d.paid_until`;
    if (rows.length === 0) console.warn('Paiement déjà traité ou montant inattendu', paymentId);
  } else if (event.type === 'checkout.session.payment_failed') {
    await sql`update payments set status = 'failed' where id = ${paymentId} and status = 'pending'`;
  }

  return json({ received: true });
}
