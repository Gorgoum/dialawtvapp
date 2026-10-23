// GET /api/paiement?statut=ok|erreur : page affichée par Wave après le paiement.
export function GET(request) {
  const ok = new URL(request.url).searchParams.get('statut') === 'ok';
  const title = ok ? 'Paiement reçu' : 'Paiement non abouti';
  const text = ok
    ? 'Merci ! Votre abonnement est activé. Retournez dans l’application Dialaw TV pour suivre le direct.'
    : 'Le paiement n’a pas été effectué. Retournez dans l’application Dialaw TV pour réessayer.';
  const html = `<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} – Dialaw TV</title>
<style>
  body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0E0C1D;
       color:#fff;font-family:system-ui,sans-serif;text-align:center;padding:24px;box-sizing:border-box}
  .icon{font-size:64px} h1{margin:12px 0 8px} p{color:#A9A6C2;max-width:340px;line-height:1.5}
</style></head>
<body><main><div class="icon">${ok ? '✅' : '⚠️'}</div><h1>${title}</h1><p>${text}</p></main></body></html>`;
  return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}
