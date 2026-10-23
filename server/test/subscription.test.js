import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { test } from 'node:test';

import { PLANS, accessStatus, isUuid, isValidDeviceId } from '../lib/subscription.js';
import { verifyWaveSignature } from '../lib/wave.js';

const now = new Date('2026-11-15T12:00:00Z');
const days = (n) => new Date(now.getTime() + n * 86400000).toISOString();

test('pendant le mois gratuit, l’accès est en essai', () => {
  const s = accessStatus({ trial_ends_at: days(10), paid_until: null }, now);
  assert.equal(s.status, 'trial');
  assert.equal(s.accessUntil, days(10));
});

test('après le mois gratuit sans paiement, l’accès est coupé', () => {
  const s = accessStatus({ trial_ends_at: days(-1), paid_until: null }, now);
  assert.equal(s.status, 'expired');
  assert.equal(s.accessUntil, null);
});

test('un abonnement payé prime sur l’essai', () => {
  const s = accessStatus({ trial_ends_at: days(5), paid_until: days(40) }, now);
  assert.equal(s.status, 'active');
  assert.equal(s.accessUntil, days(40));
});

test('un abonnement échu coupe l’accès', () => {
  const s = accessStatus({ trial_ends_at: days(-60), paid_until: days(-2) }, now);
  assert.equal(s.status, 'expired');
});

test('tarifs : 1 000 FCFA par mois, 10 000 FCFA par an', () => {
  assert.deepEqual([PLANS.monthly.amount, PLANS.monthly.months], [1000, 1]);
  assert.deepEqual([PLANS.yearly.amount, PLANS.yearly.months], [10000, 12]);
});

test('validation des identifiants', () => {
  assert.ok(isValidDeviceId('a1b2c3d4e5f60789'));
  assert.ok(!isValidDeviceId("x'; drop table devices;--"));
  assert.ok(!isValidDeviceId('court'));
  assert.ok(isUuid('3f2b8c1e-9a4d-4e2f-8b6a-1c2d3e4f5a6b'));
  assert.ok(!isUuid('pas-un-uuid'));
});

const secret = 'wave_sn_WHS_test';
const body = '{"type":"checkout.session.completed"}';
const sign = (t, b = body, s = secret) => createHmac('sha256', s).update(t + b).digest('hex');

test('signature Wave valide acceptée', () => {
  const t = Math.floor(now.getTime() / 1000);
  const header = `t=${t},v1=${sign(t)}`;
  assert.ok(verifyWaveSignature({ header, rawBody: body, secret, now: now.getTime() }));
});

test('signature Wave falsifiée, corps modifié ou trop ancienne refusée', () => {
  const t = Math.floor(now.getTime() / 1000);
  const ok = (header, rawBody = body, at = now.getTime()) =>
    verifyWaveSignature({ header, rawBody, secret, now: at });
  assert.ok(!ok(`t=${t},v1=${sign(t, body, 'autre-secret')}`));
  assert.ok(!ok(`t=${t},v1=${sign(t)}`, body.replace('completed', 'payment_failed')));
  assert.ok(!ok(`t=${t},v1=${sign(t)}`, body, now.getTime() + 10 * 60 * 1000));
  assert.ok(!ok(undefined));
  assert.ok(!ok('n-importe-quoi'));
});

test('plusieurs signatures v1 (rotation du secret) : une seule valide suffit', () => {
  const t = Math.floor(now.getTime() / 1000);
  const header = `t=${t},v1=${'00'.repeat(32)},v1=${sign(t)}`;
  assert.ok(verifyWaveSignature({ header, rawBody: body, secret, now: now.getTime() }));
});
