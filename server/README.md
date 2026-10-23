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

## Mise en ligne (une seule fois)

1. **Neon** : créer un projet (région Europe), ouvrir *SQL Editor*, coller et exécuter
   [`schema.sql`](schema.sql). Copier la chaîne de connexion (*Connect*).
2. **Vercel** : *Add New → Project*, importer le dépôt GitHub, et régler
   **Root Directory = `server`**. Dans *Environment Variables*, ajouter les variables de
   [`.env.example`](.env.example) avec les vraies valeurs, puis *Deploy*.
3. **Wave Business** (portail business.wave.com → *Développeurs*) :
   - créer une **clé API** avec l'accès *Checkout API* → `WAVE_API_KEY` ;
   - créer un **webhook** vers `https://<votre-projet>.vercel.app/api/wave-webhook`,
     méthode de sécurité *signature*, événements `checkout.session.completed` et
     `checkout.session.payment_failed` → secret dans `WAVE_WEBHOOK_SECRET` ;
   - redéployer sur Vercel après avoir ajouté les variables.
4. **Application** : mettre l'adresse Vercel dans `apiBaseUrl` de `lib/config.dart`, puis
   recompiler. Tant que `apiBaseUrl` est vide, l'abonnement est désactivé (direct gratuit).
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
