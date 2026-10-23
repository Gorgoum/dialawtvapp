// Application HTTP de l'API Dialaw TV (lancée par server.js, testée dans test/).
// Les routes de api/ sont écrites avec Request/Response (standard Web) : on les
// branche ici sur le serveur HTTP de Node.
import { createServer } from 'node:http';

import { POST as access } from './api/access.js';
import { POST as checkout } from './api/checkout.js';
import { GET as paiement } from './api/paiement.js';
import { POST as waveWebhook } from './api/wave-webhook.js';

const routes = {
  'POST /api/access': access,
  'POST /api/checkout': checkout,
  'POST /api/wave-webhook': waveWebhook,
  'GET /api/paiement': paiement,
  // Sonde de Render (healthCheckPath) : répond sans toucher à la base.
  'GET /health': () => Response.json({ ok: true }),
};

const MAX_BODY = 64 * 1024;

async function readBody(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY) throw Object.assign(new Error('Corps trop volumineux'), { status: 413 });
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

export function createApp() {
  return createServer(async (req, res) => {
    const url = new URL(req.url, `https://${req.headers.host ?? 'localhost'}`);
    const handler = routes[`${req.method} ${url.pathname}`];
    let response;
    try {
      if (!handler) {
        response = Response.json({ error: 'introuvable' }, { status: 404 });
      } else {
        const body = req.method === 'GET' ? undefined : await readBody(req);
        response = await handler(
          new Request(url, { method: req.method, headers: req.headers, body }),
        );
      }
    } catch (error) {
      console.error(req.method, url.pathname, error);
      response = Response.json(
        { error: error.status === 413 ? 'Requête trop volumineuse' : 'Erreur serveur' },
        { status: error.status ?? 500 },
      );
    }
    res.writeHead(response.status, Object.fromEntries(response.headers));
    res.end(Buffer.from(await response.arrayBuffer()));
  });
}
