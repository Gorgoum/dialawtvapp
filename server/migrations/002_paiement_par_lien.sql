-- Paiement par lien Wave Business + validation par un admin.
-- À exécuter une fois après schema.sql (console Neon → SQL Editor). Rejouable sans risque.

-- Admins nommés : chacun a son mot de passe ; chaque validation garde son nom.
create table if not exists admins (
  id            serial primary key,
  name          text not null unique,
  password_hash text not null,
  created_at    timestamptz not null default now(),
  created_by    text
);

-- Mode de paiement : API Wave (validé automatiquement) ou lien (validé par un admin).
alter table payments add column if not exists method text not null default 'wave_api';
alter table payments add column if not exists payer_phone text;
alter table payments add column if not exists reviewed_by text;
alter table payments add column if not exists reviewed_at timestamptz;

alter table payments drop constraint if exists payments_method_check;
alter table payments add constraint payments_method_check
  check (method in ('wave_api', 'wave_link'));

-- Nouveau statut « refusé » (paiement introuvable dans Wave Business).
alter table payments drop constraint if exists payments_status_check;
alter table payments add constraint payments_status_check
  check (status in ('pending', 'succeeded', 'failed', 'rejected'));

create index if not exists payments_pending_idx on payments (created_at) where status = 'pending';
