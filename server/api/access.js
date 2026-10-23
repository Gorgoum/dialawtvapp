import { touchDevice } from '../lib/db.js';
import { json, readJson } from '../lib/http.js';
import { accessStatus, isValidDeviceId } from '../lib/subscription.js';

// POST /api/access { deviceId, platform } → état de l'accès au direct.
// Le premier appel d'un appareil démarre son mois gratuit.
export async function POST(request) {
  const body = await readJson(request);
  if (!isValidDeviceId(body?.deviceId)) {
    return json({ error: 'deviceId invalide' }, 400);
  }
  const device = await touchDevice(body.deviceId, String(body.platform ?? '').slice(0, 20));
  return json(accessStatus(device));
}
