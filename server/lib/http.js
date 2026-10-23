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

/** Adresse publique du déploiement, pour les liens de retour de Wave. */
export function publicUrl(request) {
  if (process.env.PUBLIC_URL) return process.env.PUBLIC_URL.replace(/\/$/, '');
  return new URL(request.url).origin;
}
