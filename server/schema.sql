-- Base Neon de Dialaw TV : essais gratuits et abonnements au direct.
-- À exécuter une fois dans l'éditeur SQL de la console Neon.

-- Un appareil = un utilisateur (identifiant Android, conservé à la réinstallation).
create table if not exists devices (
  device_id     text primary key,
  platform      text,
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now(),
  -- Fin du mois gratuit, fixée au premier lancement de l'application.
  trial_ends_at timestamptz not null,
  -- Fin de la période payée (null tant que l'utilisateur n'a jamais payé).
  paid_until    timestamptz
);

-- Une ligne par tentative de paiement Wave.
create table if not exists payments (
  id              uuid primary key default gen_random_uuid(),
  device_id       text not null references devices (device_id),
  plan            text not null check (plan in ('monthly', 'yearly')),
  amount          integer not null,
  status          text not null default 'pending'
                  check (status in ('pending', 'succeeded', 'failed')),
  wave_session_id text unique,
  created_at      timestamptz not null default now(),
  paid_at         timestamptz
);

create index if not exists payments_device_idx on payments (device_id);
