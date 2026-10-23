import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  createSession,
  hashPassword,
  loginBlocked,
  readSession,
  recordLoginFailure,
  verifyPassword,
} from '../lib/admin-auth.js';
import { esc } from '../lib/admin-html.js';
import { formatPhone, normalizeSenegalPhone, wavePaymentUrl } from '../lib/subscription.js';

test('numéros Wave sénégalais : formats acceptés et normalisés', () => {
  for (const input of ['771234567', '77 123 45 67', '+221 77 123 45 67', '00221771234567', '221-77-123-45-67']) {
    assert.equal(normalizeSenegalPhone(input), '771234567', input);
  }
  assert.equal(normalizeSenegalPhone('70 123 45 67'), '701234567');
  assert.equal(normalizeSenegalPhone('76 000 00 00'), '760000000');
  assert.equal(formatPhone('771234567'), '77 123 45 67');
});

test('numéros refusés : fixe, trop court, étranger, vide', () => {
  for (const input of ['338201234', '7712345', '+33612345678', '', null, '79 123 45 67']) {
    assert.equal(normalizeSenegalPhone(input), null, String(input));
  }
});

test('lien Wave avec le montant pré-rempli', () => {
  assert.equal(
    wavePaymentUrl(1000, 'https://pay.wave.com/m/M_sn_test/c/sn/'),
    'https://pay.wave.com/m/M_sn_test/c/sn/?amount=1000',
  );
});

test('mot de passe admin : empreinte vérifiable, jamais en clair', async () => {
  const stored = await hashPassword('motdepasse-solide');
  assert.ok(!stored.includes('motdepasse-solide'));
  assert.ok(await verifyPassword('motdepasse-solide', stored));
  assert.ok(!(await verifyPassword('mauvais', stored)));
  assert.ok(!(await verifyPassword('x', 'format-inconnu')));
  assert.notEqual(stored, await hashPassword('motdepasse-solide'), 'sel aléatoire');
});

test('session admin : signée, falsification et expiration refusées', () => {
  const secret = 'secret-de-session';
  const now = Date.now();
  const token = createSession({ name: 'Awa', owner: false }, secret, now);
  assert.equal(readSession(token, secret, now).name, 'Awa');
  assert.equal(readSession(token, 'autre-secret', now), null);

  // Se déclarer propriétaire en modifiant le jeton invalide la signature.
  const [, signature] = token.split('.');
  const forged = Buffer.from(JSON.stringify({ name: 'Awa', owner: true, exp: now + 1e9 })).toString('base64url');
  assert.equal(readSession(`${forged}.${signature}`, secret, now), null);

  assert.equal(readSession(token, secret, now + 13 * 3600e3), null, 'expirée après 12 h');
  assert.equal(readSession(undefined, secret), null);
});

test('connexion bloquée après 5 échecs depuis la même adresse', () => {
  const ip = `test-${Math.random()}`;
  for (let i = 0; i < 4; i++) recordLoginFailure(ip);
  assert.ok(!loginBlocked(ip));
  recordLoginFailure(ip);
  assert.ok(loginBlocked(ip));
  assert.ok(!loginBlocked(ip, Date.now() + 16 * 60e3), 'débloquée après 15 min');
});

test('HTML échappé : pas d’injection de script', () => {
  assert.equal(esc('<script>alert("x")</script>'), '&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;');
  assert.equal(esc("O'Neil & co"), 'O&#39;Neil &amp; co');
});
