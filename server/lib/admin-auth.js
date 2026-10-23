import { createHmac, randomBytes, scrypt, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const scryptAsync = promisify(scrypt);
const SESSION_HOURS = 12;
export const COOKIE = 'dtv_admin';

/** Empreinte « scrypt$sel$hash » : le mot de passe lui-même n'est jamais stocké. */
export async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const hash = await scryptAsync(password, salt, 32);
  return `scrypt$${salt}$${hash.toString('hex')}`;
}

export async function verifyPassword(password, stored) {
  const [scheme, salt, hex] = String(stored).split('$');
  if (scheme !== 'scrypt' || !salt || !hex) return false;
  const expected = Buffer.from(hex, 'hex');
  const actual = await scryptAsync(password, salt, expected.length);
  return timingSafeEqual(actual, expected);
}

export function safeEqual(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && timingSafeEqual(x, y);
}

const sign = (payload, secret) => createHmac('sha256', secret).update(payload).digest('base64url');

/** Jeton de session signé : { name, owner, exp }. */
export function createSession({ name, owner }, secret, now = Date.now()) {
  const payload = Buffer.from(
    JSON.stringify({ name, owner: Boolean(owner), exp: now + SESSION_HOURS * 3600e3 }),
  ).toString('base64url');
  return `${payload}.${sign(payload, secret)}`;
}

export function readSession(token, secret, now = Date.now()) {
  if (!token || !secret) return null;
  const [payload, signature] = token.split('.');
  if (!payload || !signature || !safeEqual(signature, sign(payload, secret))) return null;
  try {
    const session = JSON.parse(Buffer.from(payload, 'base64url').toString());
    return session.exp > now ? session : null;
  } catch {
    return null;
  }
}

export function getCookie(request, name) {
  for (const part of (request.headers.get('cookie') ?? '').split(';')) {
    const [key, ...value] = part.trim().split('=');
    if (key === name) return value.join('=');
  }
  return null;
}

export function sessionCookie(token) {
  const maxAge = token ? SESSION_HOURS * 3600 : 0;
  return `${COOKIE}=${token ?? ''}; Path=/admin; HttpOnly; Secure; SameSite=Strict; Max-Age=${maxAge}`;
}

/**
 * Freine les essais de mot de passe : 5 échecs par adresse IP en 15 minutes.
 * En mémoire : suffisant pour un seul serveur Render.
 */
const failures = new Map();
const WINDOW_MS = 15 * 60e3;
const MAX_FAILURES = 5;

export function loginBlocked(ip, now = Date.now()) {
  const recent = (failures.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  failures.set(ip, recent);
  return recent.length >= MAX_FAILURES;
}

export function recordLoginFailure(ip, now = Date.now()) {
  failures.set(ip, [...(failures.get(ip) ?? []), now]);
}
