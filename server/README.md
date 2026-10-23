# API Dialaw TV – abonnements au direct

Petit serveur entre l'application, la base **Neon** et **Wave Business** :

- 1 mois gratuit au premier lancement de l'application (par appareil) ;
- puis **1 000 FCFA / mois** ou **10 000 FCFA / an**, payés avec Wave ;
- un paiement s'ajoute après l'essai ou l'abonnement en cours : on ne perd jamais de jours.

| Adresse | Rôle |
|---|---|
| `POST /api/access` | État de l'accès de l'appareil (démarre l'essai au premier appel) |
| `POST /api/checkout` | Crée le paiement Wave et renvoie le lien qui ouvre Wave |
| `POST /api/wave-webhook` | Reçu de Wave quand un paiement est terminé (signature vérifiée) |
| `GET /api/paiement` | Page affichée après le paiement |
| `GET /health` | Sonde de santé de Render |
| `POST /api/payment-claim` | **Mode actuel** : enregistre « je paie telle formule avec tel numéro Wave » et renvoie le lien Wave Business (montant pré-rempli) |
| `/admin` | **Espace admin** : les admins nommés valident ou refusent les paiements |

### Mode actuel : lien Wave Business + validation par un admin

Dialaw TV n'a pas l'API Wave : l'utilisateur paie avec le lien marchand
(`WAVE_PAYMENT_LINK`, par défaut celui de Dialaw TV). Un admin ouvre
`https://dialaw-tv-api.onrender.com/admin`, retrouve le paiement dans l'application Wave
Business (même numéro, même montant) et appuie sur **Valider** : 1 ou 12 mois sont
ajoutés. Chaque décision garde le nom de l'admin.

- **Propriétaire** : se connecte avec n'importe quel nom et `ADMIN_MASTER_PASSWORD`
  (variable Render) ; lui seul nomme et retire les admins.
- **Admins** : nom + mot de passe (10 caractères minimum) donnés par le propriétaire.
- Sécurité : mots de passe chiffrés (scrypt), session signée de 12 h (`SESSION_SECRET`),
  formulaires d'autres sites refusés, 5 essais de connexion par 15 min.
- Base : exécuter aussi [`migrations/002_paiement_par_lien.sql`](migrations/002_paiement_par_lien.sql).

Les routes `/api/checkout` et `/api/wave-webhook` (paiement automatique par l'API
Wave) restent prêtes si Wave accorde un jour l'accès à l'API.

Hébergé sur **Render** (service web Node : `npm start` lance [`server.js`](server.js)).
Les routes de [`api/`](api/) sont branchées sur le serveur HTTP dans [`app.js`](app.js).

## Mise en ligne (une seule fois)

1. **Neon** : créer un projet, ouvrir *SQL Editor*, coller et exécuter
   [`schema.sql`](schema.sql). Copier la chaîne de connexion (*Connect*).
2. **Render** : *New → Blueprint*, choisir le dépôt GitHub : le fichier
   [`render.yaml`](../render.yaml) à la racine crée le service `dialaw-tv-api` (dossier
   `server`, région Ohio comme Neon). Render demande alors les valeurs secrètes de
   [`.env.example`](.env.example) : coller au moins `DATABASE_URL` (les clés Wave peuvent
   venir plus tard), puis *Apply*. L'adresse du service ressemble à
   `https://dialaw-tv-api.onrender.com`.
3. **Wave Business** (portail business.wave.com → *Développeurs*) :
   - créer une **clé API** avec l'accès *Checkout API* → `WAVE_API_KEY` ;
   - créer un **webhook** vers `https://<service>.onrender.com/api/wave-webhook`,
     méthode de sécurité *signature*, événements `checkout.session.completed` et
     `checkout.session.payment_failed` → secret dans `WAVE_WEBHOOK_SECRET` ;
   - ajouter ces deux valeurs dans Render → *Environment* : le service redémarre seul.
4. **Application** : mettre l'adresse Render dans `apiBaseUrl` de `lib/config.dart`, puis
   recompiler. Tant que `apiBaseUrl` est vide, l'abonnement est désactivé (direct gratuit).

> **Offre gratuite de Render** : le service s'endort après 15 min sans requête et met
> 30 à 50 s à se réveiller. L'application attend jusqu'à 60 s, et Wave renvoie ses
> notifications si besoin. L'offre payante (*Starter*) supprime cette mise en veille.
5. **Test réel** : sur un téléphone, payer 1 000 FCFA, vérifier que l'accès passe à
   « Abonné » et que la ligne apparaît dans `payments` avec `status = 'succeeded'`.

> Vérifier au moment de la configuration que le format de signature décrit dans la
> documentation Wave (`Wave-Signature: t=…,v1=…`, HMAC-SHA256 de horodatage + corps) est
> toujours celui de `lib/wave.js`.

## Suivi (console Neon → SQL Editor)

```sql
-- Abonnés actifs
select count(*) from devices where paid_until > now();

-- Utilisateurs en essai
select count(*) from devices where trial_ends_at > now() and coalesce(paid_until, now()) <= now();

-- Recettes du mois en cours
select plan, count(*), sum(amount) as total_fcfa
from payments
where status = 'succeeded' and paid_at >= date_trunc('month', now())
group by plan;

-- Offrir un mois à un appareil (geste commercial, changement de téléphone…)
update devices
set paid_until = greatest(now(), coalesce(paid_until, now()), trial_ends_at) + interval '1 month'
where device_id = 'IDENTIFIANT_AFFICHÉ_DANS_L_APPLI';
```

## Tests

```sh
cd server
node --test
```
