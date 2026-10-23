export const json = (data, status = 200) =>
  Response.json(data, { status, headers: { 'Cache-Control': 'no-store' } });

/** Corps JSON de la requête, ou null s'il est absent ou invalide. */
export async function readJson(request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

/**
 * Adresse publique du serveur, pour les liens de retour de Wave : PUBLIC_URL si
 * définie, sinon celle que Render fournit (RENDER_EXTERNAL_URL), sinon la requête.
 */
export function publicUrl(request) {
  const url = process.env.PUBLIC_URL || process.env.RENDER_EXTERNAL_URL;
  if (url) return url.replace(/\/$/, '');
  return new URL(request.url).origin;
}
