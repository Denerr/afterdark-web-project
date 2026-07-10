-- Afterdark — migração: tabela de membros de mesa (jogadores conectados)
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.

create table if not exists public.table_members (
  id uuid primary key default gen_random_uuid(),
  table_id uuid not null references public.tables(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  player_name text not null default '',
  char_name text,
  char_data jsonb not null default '{}'::jsonb,
  status text not null default 'conectando',
  joined_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.table_members enable row level security;

-- table_members não contém dados sensíveis — políticas permissivas
create policy "members_select_all" on public.table_members for select using (true);
create policy "members_insert_all" on public.table_members for insert with check (true);
create policy "members_update_all" on public.table_members for update using (true);
create policy "members_delete_master" on public.table_members for delete using (
  exists(select 1 from public.tables where id = table_members.table_id and owner_id = auth.uid())
);

drop trigger if exists members_set_updated_at on public.table_members;
create trigger members_set_updated_at
  before update on public.table_members
  for each row execute function public.set_updated_at();
