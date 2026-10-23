import {
  COOKIE,
  createSession,
  getCookie,
  hashPassword,
  loginBlocked,
  readSession,
  recordLoginFailure,
  safeEqual,
  sessionCookie,
  verifyPassword,
} from '../lib/admin-auth.js';
import { dashboardPage, loginPage, page } from '../lib/admin-html.js';
import { approvePayment, rejectPayment, sql } from '../lib/db.js';
import { isUuid } from '../lib/subscription.js';

// Espace admin (/admin…) : les admins nommés valident les paiements faits avec le
// lien Wave Business. Le propriétaire (ADMIN_MASTER_PASSWORD) nomme les admins.

const html = (body, status = 200, headers = {}) =>
  new Response(body, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Frame-Options': 'DENY',
      ...headers,
    },
  });

const redirect = (location, headers = {}) =>
  new Response(null, { status: 303, headers: { Location: location, ...headers } });

const clientIp = (request) =>
  request.headers.get('x-forwarded-for')?.split(',')[0].trim() || 'inconnue';

/** Session valide et admin toujours existant (un admin retiré perd l'accès tout de suite). */
async function currentSession(request) {
  const session = readSession(getCookie(request, COOKIE), process.env.SESSION_SECRET);
  if (!session) return null;
  if (session.owner) return session;
  const rows = await sql`select 1 from admins where name = ${session.name}`;
  return rows.length ? session : null;
}

/** Formulaires : refuse ceux envoyés depuis un autre site (protection CSRF). */
function sameOrigin(request) {
  const origin = request.headers.get('origin');
  if (!origin) return true; // anciens navigateurs : le cookie SameSite=Strict protège déjà
  return new URL(origin).host === request.headers.get('host');
}

async function login(request) {
  const ip = clientIp(request);
  if (loginBlocked(ip)) {
    return html(loginPage('Trop de tentatives. Réessayez dans 15 minutes.'), 429);
  }
  const form = await request.formData();
  const name = String(form.get('name') ?? '').trim().slice(0, 40);
  const password = String(form.get('password') ?? '');

  let session = null;
  const master = process.env.ADMIN_MASTER_PASSWORD;
  if (master && name && safeEqual(password, master)) {
    session = { name, owner: true };
  } else {
    const [admin] = await sql`select name, password_hash from admins where name = ${name}`;
    if (admin && (await verifyPassword(password, admin.password_hash))) {
      session = { name: admin.name, owner: false };
    }
  }
  if (!session) {
    recordLoginFailure(ip);
    return html(loginPage('Nom ou mot de passe incorrect.'), 401);
  }
  const token = createSession(session, process.env.SESSION_SECRET);
  return redirect('/admin', { 'Set-Cookie': sessionCookie(token) });
}

async function dashboard(session, flash) {
  const [stats] = await sql`
    select
      (select count(*)::int from payments where status = 'pending') as pending,
      (select count(*)::int from devices where paid_until > now()) as active,
      (select count(*)::int from devices
        where trial_ends_at > now() and coalesce(paid_until, now()) <= now()) as trial,
      (select coalesce(sum(amount), 0)::int from payments
        where status = 'succeeded' and paid_at >= date_trunc('month', now())) as month`;
  const pending = await sql`
    select id, device_id, plan, amount, payer_phone, created_at from payments
     where status = 'pending' and method = 'wave_link'
     order by created_at asc limit 100`;
  const history = await sql`
    select plan, amount, status, payer_phone, created_at, reviewed_at, reviewed_by from payments
     where status <> 'pending'
     order by coalesce(reviewed_at, created_at) desc limit 30`;
  const admins = session.owner
    ? await sql`select id, name, created_at, created_by from admins order by name`
    : [];
  return html(dashboardPage({ session, stats, pending, history, admins, flash }));
}

const FLASH = {
  approved: 'Paiement validé : l’abonnement est actif.',
  rejected: 'Paiement refusé.',
  done: 'Ce paiement avait déjà été traité par un autre admin.',
  added: 'Admin ajouté.',
  removed: 'Accès retiré.',
  exists: 'Un admin porte déjà ce nom.',
  weak: 'Mot de passe trop court (10 caractères minimum).',
};

export async function handleAdmin(request) {
  if (!process.env.SESSION_SECRET) {
    return html(page('Indisponible', '<h1>Espace admin non configuré (SESSION_SECRET).</h1>'), 503);
  }
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/$/, '') || '/admin';
  const method = request.method;

  if (method === 'POST' && !sameOrigin(request)) {
    return html(page('Refusé', '<h1>Requête refusée.</h1>'), 403);
  }
  if (path === '/admin/login' && method === 'POST') return login(request);
  if (path === '/admin/logout' && method === 'POST') {
    return redirect('/admin', { 'Set-Cookie': sessionCookie(null) });
  }

  const session = await currentSession(request);
  if (!session) {
    return path === '/admin' && method === 'GET' ? html(loginPage()) : redirect('/admin');
  }

  if (path === '/admin' && method === 'GET') {
    return dashboard(session, FLASH[url.searchParams.get('ok')]);
  }

  const decision = path.match(/^\/admin\/payments\/([^/]+)\/(approve|reject)$/);
  if (decision && method === 'POST') {
    const [, id, action] = decision;
    if (!isUuid(id)) return redirect('/admin');
    const done =
      action === 'approve'
        ? await approvePayment(id, session.name)
        : await rejectPayment(id, session.name);
    return redirect(`/admin?ok=${done ? (action === 'approve' ? 'approved' : 'rejected') : 'done'}`);
  }

  if (session.owner && path === '/admin/admins' && method === 'POST') {
    const form = await request.formData();
    const name = String(form.get('name') ?? '').trim().slice(0, 40);
    const password = String(form.get('password') ?? '');
    if (!name) return redirect('/admin');
    if (password.length < 10) return redirect('/admin?ok=weak');
    const rows = await sql`
      insert into admins (name, password_hash, created_by)
      values (${name}, ${await hashPassword(password)}, ${session.name})
      on conflict (name) do nothing returning id`;
    return redirect(`/admin?ok=${rows.length ? 'added' : 'exists'}`);
  }

  const removal = path.match(/^\/admin\/admins\/(\d+)\/delete$/);
  if (session.owner && removal && method === 'POST') {
    await sql`delete from admins where id = ${Number(removal[1])}`;
    return redirect('/admin?ok=removed');
  }

  return redirect('/admin');
}
