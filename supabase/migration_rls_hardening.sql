-- Afterdark — migração: fecha vazamento de listagem de mesas e reforça table_members
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.

-- 1) tables: remove a condição que liberava listar TODAS as mesas do sistema
--    (antes: "auth.uid() = owner_id OR invite_code is not null", e toda mesa
--    tem invite_code, entao na pratica qualquer um lia a tabela inteira).
drop policy if exists "tables_select_own" on public.tables;
create policy "tables_select_own" on public.tables
  for select using (auth.uid() = owner_id);

-- Funcao segura que busca UMA mesa pelo codigo de convite (usada no fluxo de
-- "entrar com codigo"), sem expor a listagem geral da tabela tables.
create or replace function public.get_table_by_invite_code(p_code text)
returns table(id uuid, name text, type text, theme text)
language sql
security definer
set search_path = public
as $$
  select t.id, t.name, t.type, t.theme
  from public.tables t
  where t.invite_code = p_code;
$$;

grant execute on function public.get_table_by_invite_code(text) to anon, authenticated;

-- 2) table_members: insert continua liberado (a foreign key table_id->tables.id
--    ja garante que nao da pra apontar pra uma mesa inexistente; uma checagem
--    extra via EXISTS aqui falharia pra quem nao e dono da mesa, ja que agora
--    "tables" so libera SELECT pro proprio dono).
drop policy if exists "members_insert_all" on public.table_members;
create policy "members_insert_all" on public.table_members
  for insert with check (true);

-- 3) table_members: update permitido pro dono da mesa, pelo proprio jogador
--    logado (auth.uid() = user_id), ou por linhas de jogador sem conta
--    (user_id nulo) -- mantendo o suporte a "entrar sem cadastro" ja existente.
--    Isso impede que qualquer pessoa edite a ficha de um jogador LOGADO em
--    qualquer mesa, que era o problema antes (policy com using(true)).
drop policy if exists "members_update_all" on public.table_members;
drop policy if exists "members_update_own_or_master" on public.table_members;
create policy "members_update_own_or_master" on public.table_members
  for update using (
    auth.uid() = user_id
    or user_id is null
    or exists(select 1 from public.tables where id = table_members.table_id and owner_id = auth.uid())
  );

-- 4) indice para o polling frequente por table_id (lobby do mestre e do jogador)
create index if not exists table_members_table_id_idx on public.table_members(table_id);

-- 5) funcao segura pro jogador checar o status da propria mesa (ele nao e
--    dono, entao nao tem SELECT em tables; o polling do lobby do jogador
--    precisa saber quando o Mestre iniciou a sessao).
create or replace function public.get_table_status(p_id uuid)
returns text
language sql
security definer
set search_path = public
as $$
  select status from public.tables where id = p_id;
$$;

grant execute on function public.get_table_status(uuid) to anon, authenticated;
