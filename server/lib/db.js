import { neon } from '@neondatabase/serverless';

import { TRIAL_DAYS } from './subscription.js';

// Connexion HTTP sans état (driver Neon) : pas de pool à gérer ni à fermer.
export const sql = neon(process.env.DATABASE_URL);

/** Dernière demande de paiement par lien de l'appareil (14 derniers jours), ou null. */
export async function lastLinkPayment(deviceId) {
  const rows = await sql`
    select id, plan, amount, status, payer_phone, created_at, reviewed_at
      from payments
     where device_id = ${deviceId}
       and method = 'wave_link'
       and created_at > now() - interval '14 days'
     order by created_at desc
     limit 1`;
  return rows[0] ?? null;
}

/**
 * Validation par un admin : passe le paiement à « réussi » (une seule fois) et
 * ajoute 1 ou 12 mois après l'essai ou l'abonnement en cours. null si déjà traité.
 */
export async function approvePayment(paymentId, adminName) {
  const rows = await sql`
    with paid as (
      update payments
         set status = 'succeeded', paid_at = now(), reviewed_by = ${adminName}, reviewed_at = now()
       where id = ${paymentId} and status = 'pending' and method = 'wave_link'
      returning device_id, plan
    )
    update devices d
       set paid_until = greatest(now(), coalesce(d.paid_until, now()), d.trial_ends_at)
                        + make_interval(months => case paid.plan when 'yearly' then 12 else 1 end)
      from paid
     where d.device_id = paid.device_id
    returning d.paid_until`;
  return rows[0] ?? null;
}

export async function rejectPayment(paymentId, adminName) {
  const rows = await sql`
    update payments
       set status = 'rejected', reviewed_by = ${adminName}, reviewed_at = now()
     where id = ${paymentId} and status = 'pending' and method = 'wave_link'
    returning id`;
  return rows.length > 0;
}

/** Enregistre l'appareil au premier contact (début du mois gratuit) et le renvoie. */
export async function touchDevice(deviceId, platform) {
  const rows = await sql`
    insert into devices (device_id, platform, trial_ends_at)
    values (${deviceId}, ${platform ?? null}, now() + make_interval(days => ${TRIAL_DAYS}))
    on conflict (device_id) do update set last_seen_at = now()
    returning *`;
  return rows[0];
}
