import { formatPhone } from './subscription.js';

/** Échappe le texte inséré dans le HTML (numéros, noms d'admin…). */
export const esc = (value) =>
  String(value ?? '').replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c],
  );

const dateFmt = new Intl.DateTimeFormat('fr-FR', {
  timeZone: 'Africa/Dakar',
  day: 'numeric',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
});
export const fmtDate = (d) => (d ? dateFmt.format(new Date(d)) : '');
const fcfa = (n) => `${new Intl.NumberFormat('fr-FR').format(n)} FCFA`.replace(/ /g, ' ');
const planLabel = (p) => (p === 'yearly' ? 'Annuel' : 'Mensuel');

const STATUS = {
  succeeded: ['Validé', 'ok'],
  rejected: ['Refusé', 'ko'],
  pending: ['En attente', 'wait'],
  failed: ['Échec', 'ko'],
};

export function page(title, body) {
  return `<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${esc(title)} – Dialaw TV</title>
<style>
  :root{--bg:#0E0C1D;--card:#18152E;--line:#2F2A52;--text:#fff;--muted:#A9A6C2;--red:#CE0000;--green:#1F9D55;--orange:#FF9F0A}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--text);font:16px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
  main{max-width:760px;margin:0 auto;padding:16px}
  header{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:16px}
  h1{font-size:20px;margin:0} h2{font-size:15px;color:var(--muted);text-transform:uppercase;letter-spacing:.08em;margin:28px 0 10px}
  .card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px;margin-bottom:10px}
  .stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px}
  .stat b{display:block;font-size:24px} .stat span{color:var(--muted);font-size:13px}
  .claim{display:flex;flex-wrap:wrap;gap:10px;align-items:center;justify-content:space-between}
  .phone{font-size:20px;font-weight:800;letter-spacing:.02em}
  .muted{color:var(--muted);font-size:14px}
  .actions{display:flex;gap:8px;flex-wrap:wrap}
  button,.btn{font:inherit;font-weight:700;border:0;border-radius:10px;padding:10px 16px;cursor:pointer;color:#fff;text-decoration:none;display:inline-block}
  .ok{background:var(--green)} .ko{background:var(--red)} .ghost{background:transparent;border:1px solid var(--line);color:var(--text)}
  .wait{background:var(--orange)}
  .badge{font-size:12px;font-weight:800;padding:2px 8px;border-radius:6px;color:#fff}
  input{font:inherit;width:100%;padding:12px;border-radius:10px;border:1px solid var(--line);background:#0B0A18;color:#fff;margin:6px 0 12px}
  label{font-size:14px;color:var(--muted)}
  table{width:100%;border-collapse:collapse;font-size:14px} td,th{padding:8px 6px;border-bottom:1px solid var(--line);text-align:left}
  .scroll{overflow-x:auto} .flash{border-color:var(--green)} .error{border-color:var(--red)}
  a{color:#9F8CFF}
</style></head><body><main>${body}</main></body></html>`;
}

export function loginPage(error = '') {
  return page(
    'Connexion admin',
    `<h1>Dialaw TV · Espace admin</h1>
     <p class="muted">Validation des paiements Wave des abonnements.</p>
     ${error ? `<div class="card error">${esc(error)}</div>` : ''}
     <form method="post" action="/admin/login" class="card">
       <label for="name">Nom</label>
       <input id="name" name="name" autocomplete="username" required>
       <label for="password">Mot de passe</label>
       <input id="password" name="password" type="password" autocomplete="current-password" required>
       <button class="ok" type="submit">Se connecter</button>
     </form>`,
  );
}

export function dashboardPage({ session, stats, pending, history, admins, flash }) {
  const claims = pending.length
    ? pending
        .map(
          (p) => `<div class="card claim">
        <div>
          <div class="phone">${esc(formatPhone(p.payer_phone))}</div>
          <div><b>${planLabel(p.plan)} · ${fcfa(p.amount)}</b></div>
          <div class="muted">Demandé le ${esc(fmtDate(p.created_at))} · appareil ${esc(p.device_id)}</div>
          <div class="muted"><a href="https://wa.me/221${esc(p.payer_phone)}" target="_blank" rel="noopener">Écrire sur WhatsApp</a></div>
        </div>
        <div class="actions">
          <form method="post" action="/admin/payments/${esc(p.id)}/approve"
                onsubmit="return confirm('Valider ${fcfa(p.amount)} du ${esc(formatPhone(p.payer_phone))} ? Vérifiez d’abord dans Wave Business.')">
            <button class="ok">Valider</button></form>
          <form method="post" action="/admin/payments/${esc(p.id)}/reject"
                onsubmit="return confirm('Refuser ce paiement (introuvable dans Wave Business) ?')">
            <button class="ko">Refuser</button></form>
        </div>
      </div>`,
        )
        .join('')
    : '<div class="card muted">Aucun paiement en attente. 👍</div>';

  const rows = history
    .map((h) => {
      const [label, cls] = STATUS[h.status] ?? [h.status, 'ghost'];
      return `<tr><td>${esc(fmtDate(h.reviewed_at ?? h.created_at))}</td>
        <td>${esc(formatPhone(h.payer_phone ?? ''))}</td><td>${fcfa(h.amount)}</td>
        <td><span class="badge ${cls}">${label}</span></td><td>${esc(h.reviewed_by ?? '')}</td></tr>`;
    })
    .join('');

  const adminSection = session.owner
    ? `<h2>Admins</h2>
       <div class="card">
         <table>${admins
           .map(
             (a) => `<tr><td><b>${esc(a.name)}</b><div class="muted">ajouté le ${esc(fmtDate(a.created_at))}${a.created_by ? ` par ${esc(a.created_by)}` : ''}</div></td>
             <td style="text-align:right"><form method="post" action="/admin/admins/${a.id}/delete"
                 onsubmit="return confirm('Retirer l’accès de ${esc(a.name)} ?')"><button class="ghost">Retirer</button></form></td></tr>`,
           )
           .join('') || '<tr><td class="muted">Aucun admin pour l’instant.</td></tr>'}</table>
       </div>
       <form method="post" action="/admin/admins" class="card">
         <b>Nommer un admin</b>
         <label for="new-name">Nom</label><input id="new-name" name="name" required maxlength="40">
         <label for="new-pass">Mot de passe (10 caractères minimum)</label>
         <input id="new-pass" name="password" type="password" required minlength="10" autocomplete="new-password">
         <button class="ok">Ajouter</button>
       </form>`
    : '';

  return page(
    'Paiements',
    `<header><h1>Dialaw TV · Paiements</h1>
       <form method="post" action="/admin/logout"><span class="muted">${esc(session.name)}${session.owner ? ' (propriétaire)' : ''}</span>
       <button class="ghost">Déconnexion</button></form></header>
     ${flash ? `<div class="card flash">${esc(flash)}</div>` : ''}
     <div class="stats">
       <div class="card stat"><b>${stats.pending}</b><span>en attente</span></div>
       <div class="card stat"><b>${stats.active}</b><span>abonnés actifs</span></div>
       <div class="card stat"><b>${stats.trial}</b><span>en essai gratuit</span></div>
       <div class="card stat"><b>${fcfa(stats.month)}</b><span>validés ce mois-ci</span></div>
     </div>
     <h2>À valider</h2>
     <p class="muted">Ouvrez Wave Business, retrouvez le paiement (même numéro, même montant), puis validez.</p>
     ${claims}
     <h2>Dernières décisions</h2>
     <div class="card scroll"><table>
       <tr><th>Date</th><th>Numéro</th><th>Montant</th><th>Statut</th><th>Par</th></tr>
       ${rows || '<tr><td colspan="5" class="muted">Rien pour l’instant.</td></tr>'}
     </table></div>
     ${adminSection}`,
  );
}
