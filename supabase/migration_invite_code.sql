-- Afterdark — migração: adiciona invite_code à tabela tables existente
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.

alter table public.tables
  add column if not exists invite_code text unique;

-- Atualiza a policy de select para permitir busca por invite_code (para jogadores entrarem)
drop policy if exists "tables_select_own" on public.tables;
create policy "tables_select_own" on public.tables
  for select using (auth.uid() = owner_id or invite_code is not null);
