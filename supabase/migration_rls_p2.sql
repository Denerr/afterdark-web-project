-- Afterdark — migração (Ponto 2): permissões e separação de conteúdo.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente: pode ser executada de novo sem duplicar objetos.
--
-- O que esta etapa fecha:
--   a) table_members tinha "select using (true)": qualquer anon lia TODOS os
--      membros de TODAS as mesas (ficha completa, ferimentos, condições).
--      Agora só o dono da mesa lê direto; o jogador usa player_get_lobby.
--   b) table_members tinha "insert with check (true)" e update/delete com o
--      ramo "user_id is null", que deixava um visitante editar/remover a linha
--      de outro visitante sem conta. Agora insert/update/delete direto é só do
--      dono; o jogador age pelas funções com token (Ponto 1) e player_leave_table.
--   c) get_table_session_state(p_id) era security definer, concedida a anon e
--      SEM checar vínculo, devolvendo o session_state inteiro — inclusive
--      relógios ocultos, NPCs não revelados, pistas ocultas e o log do mestre.
--      Substituída por player_get_session, que valida o vínculo e FILTRA no banco.
--   d) get_table_status(p_id) aceitava qualquer UUID de mesa. O status agora vem
--      dentro de player_get_state/player_get_lobby, já autorizado.
--   e) get_table_by_invite_code não é mais usada pelo app (join_table_by_code a
--      substituiu) e foi removida.
--
-- Visibilidade do log (decisão desta etapa): cada entrada tem "vis":
--   'todos'      -> mesa inteira
--   'mestre'     -> só o mestre
--   <member_id>  -> só aquele jogador (e o mestre)
--   ausente      -> tratada como 'mestre' (log legado não vaza para jogadores)
--
-- Espectador (&obs=1) NÃO é um papel autorizado nesta etapa. Ver ACESSO.md.

-- ---------------------------------------------------------------------------
-- 1) Auxiliar interno: mesa de um membro
-- ---------------------------------------------------------------------------
create or replace function public._ad_member_table(p_member_id uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select table_id from public.table_members where id = p_member_id;
$$;
revoke all on function public._ad_member_table(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) table_members: acesso direto passa a ser exclusivo do dono da mesa
-- ---------------------------------------------------------------------------
drop policy if exists "members_select_all" on public.table_members;
drop policy if exists "members_select_owner" on public.table_members;
create policy "members_select_owner" on public.table_members for select to authenticated
  using (exists(select 1 from public.tables t where t.id = table_members.table_id and t.owner_id = auth.uid()));

-- Sem policy de insert: entrar na mesa é só por join_table_by_code (security definer).
drop policy if exists "members_insert_all" on public.table_members;

-- Update direto: só o dono. O jogador escreve por player_submit_sheet /
-- player_set_ready (Ponto 1), que validam token ou auth.uid().
drop policy if exists "members_update_all" on public.table_members;
drop policy if exists "members_update_own_or_master" on public.table_members;
drop policy if exists "members_update_owner" on public.table_members;
create policy "members_update_owner" on public.table_members for update to authenticated
  using (exists(select 1 from public.tables t where t.id = table_members.table_id and t.owner_id = auth.uid()));

-- Delete direto: só o dono (remover jogador da mesa). O jogador sai por
-- player_leave_table, que exige token ou auth.uid().
drop policy if exists "members_delete_master" on public.table_members;
drop policy if exists "members_delete_own_or_master" on public.table_members;
drop policy if exists "members_delete_owner" on public.table_members;
create policy "members_delete_owner" on public.table_members for delete to authenticated
  using (exists(select 1 from public.tables t where t.id = table_members.table_id and t.owner_id = auth.uid()));

revoke all on public.table_members from anon;

-- ---------------------------------------------------------------------------
-- 3) Funções antigas e permissivas: removidas
-- ---------------------------------------------------------------------------
drop function if exists public.get_table_session_state(uuid);
drop function if exists public.get_table_status(uuid);
drop function if exists public.get_table_by_invite_code(text);

-- ---------------------------------------------------------------------------
-- 4) Lobby do jogador: status da mesa + visão pública dos membros
--    Inclui ferimentos e condições dos colegas (decisão desta etapa), mas NÃO
--    a ficha completa (atributos, perícias, fraquezas, histórico) de terceiros.
-- ---------------------------------------------------------------------------
create or replace function public.player_get_lobby(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_table uuid; v_status text; v_members jsonb;
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  v_table := public._ad_member_table(p_member_id);
  if v_table is null then raise exception 'not_authorized' using errcode = '42501'; end if;
  select status into v_status from public.tables where id = v_table;
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', m.id,
      'player_name', m.player_name,
      'char_name', m.char_name,
      'status', m.status,
      'char_data', jsonb_build_object('sens', m.char_data->'sens'),
      'wounds', m.wounds,
      'conditions', m.conditions,
      'sheet_ready', m.sheet_ready,
      'approved_at', m.approved_at
    ) order by m.joined_at), '[]'::jsonb) into v_members
    from public.table_members m where m.table_id = v_table;
  return jsonb_build_object('table_status', v_status, 'members', v_members);
end $$;

-- ---------------------------------------------------------------------------
-- 5) Estado da sessão FILTRADO no banco, por destinatário
-- ---------------------------------------------------------------------------
create or replace function public.player_get_session(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_table uuid; st jsonb; mid text;
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  v_table := public._ad_member_table(p_member_id);
  if v_table is null then raise exception 'not_authorized' using errcode = '42501'; end if;
  mid := p_member_id::text;
  select coalesce(session_state, '{}'::jsonb) into st from public.tables where id = v_table;
  if st is null or st = '{}'::jsonb then return '{}'::jsonb; end if;

  return jsonb_build_object(
    -- relógios: os da mesa visíveis, mais os dirigidos a este jogador.
    -- vis='mestre' cobre visMode mestre/avancar/completar (ver createClock).
    'clocks', coalesce((
      select jsonb_agg(c order by ord)
      from jsonb_array_elements(coalesce(st->'clocks','[]'::jsonb)) with ordinality as e(c, ord)
      where c->>'vis' = 'todos'
         or (c->>'vis' = 'jogador' and c->>'playerId' = mid)
    ), '[]'::jsonb),

    -- NPCs: só os revelados ao grupo (reveal >= 3). Abaixo disso o jogador não
    -- recebe a linha, nem borrada — a tela dele já só listava os conhecidos.
    'npcs', coalesce((
      select jsonb_agg(n order by ord)
      from jsonb_array_elements(coalesce(st->'npcs','[]'::jsonb)) with ordinality as e(n, ord)
      where coalesce((n->>'reveal')::int, 1) >= 3
    ), '[]'::jsonb),

    -- pistas: tudo que não está oculto
    'clues', coalesce((
      select jsonb_agg(k order by ord)
      from jsonb_array_elements(coalesce(st->'clues','[]'::jsonb)) with ordinality as e(k, ord)
      where coalesce(k->>'status', 'oculta') <> 'oculta'
    ), '[]'::jsonb),

    -- estresse: as barras do próprio jogador e as sem dono (mesa)
    'stressBars', coalesce((
      select jsonb_agg(b order by ord)
      from jsonb_array_elements(coalesce(st->'stressBars','[]'::jsonb)) with ordinality as e(b, ord)
      where coalesce(b->>'playerId', '') in ('', mid)
    ), '[]'::jsonb),

    -- log: só o que é da mesa ou dirigido a este jogador. Entrada sem "vis"
    -- (log legado) fica com o mestre.
    'log', coalesce((
      select jsonb_agg(l order by ord)
      from jsonb_array_elements(coalesce(st->'log','[]'::jsonb)) with ordinality as e(l, ord)
      where l->>'vis' = 'todos' or l->>'vis' = mid
    ), '[]'::jsonb),

    -- cena, inventário e biblioteca são o conteúdo público da mesa
    'scene', coalesce(st->'scene', '{}'::jsonb),
    'inventory', coalesce(st->'inventory', '{}'::jsonb),
    'library', coalesce(st->'library', '{}'::jsonb)
  );
end $$;

-- ---------------------------------------------------------------------------
-- 6) Sair da mesa pelo próprio jogador (substitui o delete direto)
-- ---------------------------------------------------------------------------
create or replace function public.player_leave_table(p_member_id uuid, p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  perform set_config('afterdark.trusted', 'on', true);
  delete from public.table_members where id = p_member_id;
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------------
-- 7) player_get_state: agora devolve também o status da mesa, para o jogador
--    não depender de get_table_status (removida no item 3).
-- ---------------------------------------------------------------------------
create or replace function public.player_get_state(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare m record; reqs jsonb; v_status text;
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select id, table_id, player_name, char_name, char_data, status, wounds, conditions, sheet_ready, approved_at
    into m from public.table_members where id = p_member_id;
  select status into v_status from public.tables where id = m.table_id;
  select coalesce(jsonb_agg(x order by x.created_at), '[]'::jsonb) into reqs from (
    (select r.id, r.kind, r.params, r.status, r.result, r.created_at, r.answered_at
       from public.table_requests r where r.target_member_id = p_member_id and r.status = 'pendente')
    union all
    (select r.id, r.kind, r.params, r.status, r.result, r.created_at, r.answered_at
       from public.table_requests r where r.target_member_id = p_member_id and r.status <> 'pendente'
       order by r.created_at desc limit 10)
  ) x;
  return jsonb_build_object(
    'member', jsonb_build_object('id', m.id, 'table_id', m.table_id, 'player_name', m.player_name,
      'char_name', m.char_name, 'char_data', m.char_data, 'status', m.status,
      'wounds', m.wounds, 'conditions', m.conditions, 'sheet_ready', m.sheet_ready,
      'approved', m.approved_at is not null),
    'table_status', v_status,
    'requests', reqs);
end $$;

-- ---------------------------------------------------------------------------
-- 8) Grants
-- ---------------------------------------------------------------------------
revoke all on function public.player_get_lobby(uuid, text) from public;
revoke all on function public.player_get_session(uuid, text) from public;
revoke all on function public.player_leave_table(uuid, text) from public;
revoke all on function public.player_get_state(uuid, text) from public;

grant execute on function public.player_get_lobby(uuid, text) to anon, authenticated;
grant execute on function public.player_get_session(uuid, text) to anon, authenticated;
grant execute on function public.player_leave_table(uuid, text) to anon, authenticated;
grant execute on function public.player_get_state(uuid, text) to anon, authenticated;
