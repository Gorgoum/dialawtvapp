import { neon } from '@neondatabase/serverless';

import { TRIAL_DAYS } from './subscription.js';

// Connexion HTTP sans état (driver Neon) : pas de pool à gérer ni à fermer.
export const sql = neon(process.env.DATABASE_URL);

/** Enregistre l'appareil au premier contact (début du mois gratuit) et le renvoie. */
export async function touchDevice(deviceId, platform) {
  const rows = await sql`
    insert into devices (device_id, platform, trial_ends_at)
    values (${deviceId}, ${platform ?? null}, now() + make_interval(days => ${TRIAL_DAYS}))
    on conflict (device_id) do update set last_seen_at = now()
    returning *`;
  return rows[0];
}
