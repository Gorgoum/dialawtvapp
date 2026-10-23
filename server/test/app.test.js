import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

// Adresse fictive : ces tests s'arrêtent avant toute requête à la base.
process.env.DATABASE_URL ??= 'postgresql://test:test@localhost/test';
process.env.WAVE_WEBHOOK_SECRET ??= 'secret-de-test';
const { createApp } = await import('../app.js');

let server;
let base;

before(async () => {
  server = createApp();
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => server.close());

test('GET /health répond sans toucher à la base', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true });
});

test('route ou méthode inconnue : 404', async () => {
  assert.equal((await fetch(`${base}/inconnu`)).status, 404);
  assert.equal((await fetch(`${base}/api/access`)).status, 404, 'GET au lieu de POST');
});

test('POST /api/access avec un identifiant invalide : 400', async () => {
  const res = await fetch(`${base}/api/access`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ deviceId: "x'; drop table devices;--" }),
  });
  assert.equal(res.status, 400);
});

test('POST /api/checkout avec une formule inconnue : 400', async () => {
  const res = await fetch(`${base}/api/checkout`, {
    method: 'POST',
    body: JSON.stringify({ deviceId: 'a_1234567890abcdef', plan: 'gratuit' }),
  });
  assert.equal(res.status, 400);
});

test('GET /api/paiement : page de retour en HTML', async () => {
  const ok = await fetch(`${base}/api/paiement?statut=ok`);
  assert.match(ok.headers.get('content-type'), /text\/html/);
  assert.match(await ok.text(), /Paiement reçu/);
  assert.match(await (await fetch(`${base}/api/paiement?statut=erreur`)).text(), /non abouti/);
});

test('POST /api/wave-webhook sans signature valide : 401', async () => {
  const res = await fetch(`${base}/api/wave-webhook`, {
    method: 'POST',
    headers: { 'Wave-Signature': 't=1,v1=00' },
    body: '{"type":"checkout.session.completed"}',
  });
  assert.equal(res.status, 401);
});

test('corps trop volumineux : 413', async () => {
  const res = await fetch(`${base}/api/access`, {
    method: 'POST',
    body: 'x'.repeat(100 * 1024),
  });
  assert.equal(res.status, 413);
});
