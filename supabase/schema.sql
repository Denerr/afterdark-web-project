-- Afterdark — schema de personagens e mesas
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Cada usuario so enxerga e mexe nos proprios registros (RLS por owner_id).

create extension if not exists pgcrypto;

create table if not exists public.characters (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tables (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  type text not null default 'One-shot',
  faction text,
  theme text,
  status text not null default 'Aguardando jogadores',
  invite_code text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, name)
);

alter table public.characters enable row level security;
alter table public.tables enable row level security;

create policy "characters_select_own" on public.characters
  for select using (auth.uid() = owner_id);
create policy "characters_insert_own" on public.characters
  for insert with check (auth.uid() = owner_id);
create policy "characters_update_own" on public.characters
  for update using (auth.uid() = owner_id);
create policy "characters_delete_own" on public.characters
  for delete using (auth.uid() = owner_id);

-- Dono vê suas próprias mesas; qualquer um pode buscar pelo invite_code (para entrar)
create policy "tables_select_own" on public.tables
  for select using (auth.uid() = owner_id or invite_code is not null);
create policy "tables_insert_own" on public.tables
  for insert with check (auth.uid() = owner_id);
create policy "tables_update_own" on public.tables
  for update using (auth.uid() = owner_id);
create policy "tables_delete_own" on public.tables
  for delete using (auth.uid() = owner_id);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists characters_set_updated_at on public.characters;
create trigger characters_set_updated_at
  before update on public.characters
  for each row execute function public.set_updated_at();

drop trigger if exists tables_set_updated_at on public.tables;
create trigger tables_set_updated_at
  before update on public.tables
  for each row execute function public.set_updated_at();
