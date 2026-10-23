// Point d'entrée sur Render (service web Node) : écoute sur le port fourni.
import { createApp } from './app.js';

const port = Number(process.env.PORT ?? 3000);
createApp().listen(port, () => console.log(`API Dialaw TV sur le port ${port}`));
