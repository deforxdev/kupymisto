create table if not exists public.app_state (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

comment on table public.app_state is
  'Private server-owned snapshot for the Kupymisto Go API.';

alter table public.app_state enable row level security;
