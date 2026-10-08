-- Afterdark — migração (Pós-sessão, Etapas 3 e 4): estresse vinculado, penalidades,
-- revelação e conclusão dos relógios.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_scenes.sql (Etapa 2).
--
-- Relógios e barras de estresse continuam no estado da sessão (session_state), mas os
-- AVANÇOS passam a ser feitos no banco, numa operação só (master_clock_op), com a linha
-- da mesa travada. Avanço manual e avanço por estresse usam a mesma regra
-- (_ad_clock_step):
--   * Parcial  -> revela quando o progresso atinge ceil(segmentos/2) (5 -> no 3º).
--   * Completo -> revela ao completar.
--   * Ao avançar -> revela no primeiro avanço (criar no zero não revela).
--   * Revelado fica revelado, mesmo se o progresso cair. Ocultar é ação explícita.
-- Estresse (decisão de 08/10/2026): barra que enche com relógio vinculado avança esse
-- relógio em 1 e volta a zero, sem levar excedente. Relógio já completo: a barra zera,
-- o relógio fica completo e não há nova conclusão. Sem vínculo, a barra para no máximo
-- (comportamento anterior). A regra antiga "relógio completo aumenta o estresse" saiu.
--
-- Conclusão: quando um relógio passa de incompleto a completo, o banco grava um evento
-- (session_state.clockEvents) com id próprio. O jogador recebe os eventos destinados a
-- ele que ainda não confirmou (player_ack_events grava a ciência por participante).
-- Relógio "Só mestre" não gera aviso aos jogadores (decisão 6). Nenhum evento é criado
-- por esta migração: relógio que já estava completo não gera aviso.
--
-- Idempotência: cada operação traz uma chave (p_op_key). Repetir a mesma chave (clique
-- duplo, reenvio) devolve o estado atual sem aplicar de novo.
--
-- Penalidades: table_members.penalties, alteradas só pelo Mestre (master_set_penalty).
-- O valor base do atributo não muda; o app calcula o efetivo (soma das penalidades do
-- atributo, mínimo 0) e o usa nos testes. Só o próprio jogador e o Mestre as veem.
--
-- Ordem: aplicar ANTES de publicar o index.html das Etapas 3 e 4.

alter table public.table_members
  add column if not exists penalties jsonb not null default '[]'::jsonb,
  add column if not exists acked_events jsonb not null default '[]'::jsonb;

create table if not exists public._ad_session_ops (
  table_id uuid not null references public.tables(id) on delete cascade,
  op_key uuid not null,
  created_at timestamptz not null default now(),
  primary key (table_id, op_key)
);
alter table public._ad_session_ops enable row level security;
revoke all on public._ad_session_ops from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Regra única de avanço de relógio (manual e por estresse)
-- ---------------------------------------------------------------------------
create or replace function public._ad_clock_step(c jsonb, p_delta int,
  out clk jsonb, out completed boolean, out revealed boolean)
language plpgsql immutable set search_path = public as $$
declare v_seg int; v_old int; v_new int; v_mode text; v_scope text; v_vis text; v_done boolean; v_fire boolean := false;
begin
  v_seg := greatest(1, coalesce(nullif(c->>'seg','')::int, 8));
  v_old := least(v_seg, greatest(0, coalesce(nullif(c->>'fill','')::int, 0)));
  v_new := least(v_seg, greatest(0, v_old + coalesce(p_delta, 0)));
  v_mode := coalesce(c->>'visMode', case when c->>'scope' = 'player' then 'jogador' when c->>'vis' = 'mestre' then 'mestre' else 'todos' end);
  v_scope := coalesce(c->>'scope', case when v_mode = 'jogador' then 'player' else 'mesa' end);
  v_vis := coalesce(c->>'vis', case when v_mode in ('mestre','avancar','completar','parcial') then 'mestre' when v_mode = 'jogador' then 'jogador' else 'todos' end);
  v_done := coalesce((c->>'revealDone')::boolean, v_vis <> 'mestre');
  revealed := false;
  if not v_done and v_vis = 'mestre' then
    v_fire := case v_mode
      when 'avancar'   then p_delta > 0 and v_new > v_old
      when 'completar' then v_new >= v_seg
      when 'parcial'   then v_new >= ceil(v_seg / 2.0)
      else false end;
    if v_fire then
      v_vis := case when v_scope = 'player' or v_mode = 'jogador' then 'jogador' else 'todos' end;
      v_done := true; revealed := true;
    end if;
  end if;
  completed := v_old < v_seg and v_new >= v_seg;
  clk := c || jsonb_build_object('seg', v_seg, 'fill', v_new, 'visMode', v_mode, 'scope', v_scope, 'vis', v_vis, 'revealDone', v_done);
end $$;
revoke all on function public._ad_clock_step(jsonb, int) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Operação do Mestre: 'clock' {clockId, delta} ou 'stress' {barId, delta}
-- ---------------------------------------------------------------------------
create or replace function public.master_clock_op(p_table_id uuid, p_op text, p_args jsonb, p_op_key uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  st jsonb; v_ver bigint; v_delta int; v_id text; i int; c jsonb; b jsonb; r record;
  v_events jsonb := '[]'::jsonb; v_logs jsonb := '[]'::jsonb; v_level int; v_max int; v_clock_id text;
  v_char text; v_ev jsonb; v_clk_idx int; v_stress_filled boolean := false;
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_op not in ('clock','stress') or p_op_key is null or p_args is null then raise exception 'invalid_request' using errcode = '22023'; end if;
  v_delta := coalesce((p_args->>'delta')::int, 0);
  if v_delta not in (-1, 1) then raise exception 'invalid_request' using errcode = '22023'; end if;
  -- trava a mesa: duas operações (dois dispositivos, dois personagens) entram em fila
  select coalesce(session_state, '{}'::jsonb), session_version into st, v_ver from public.tables where id = p_table_id for update;
  if exists(select 1 from public._ad_session_ops where table_id = p_table_id and op_key = p_op_key) then
    return jsonb_build_object('ok', true, 'dup', true, 'state', st, 'version', v_ver, 'events', '[]'::jsonb);
  end if;

  if p_op = 'clock' then
    v_clock_id := p_args->>'clockId';
  else
    v_id := p_args->>'barId';
    select ord - 1, e into i, b from jsonb_array_elements(coalesce(st->'stressBars','[]'::jsonb)) with ordinality as x(e, ord)
     where e->>'id' = v_id limit 1;
    if b is null then raise exception 'not_found' using errcode = 'P0002'; end if;
    v_max := greatest(1, coalesce(nullif(b->>'max','')::int, 4));
    v_level := least(v_max, greatest(0, coalesce(nullif(b->>'level','')::int, 0) + v_delta));
    select coalesce(nullif(char_name,''), nullif(player_name,''), 'Personagem') into v_char
      from public.table_members where id::text = b->>'playerId';
    v_char := coalesce(v_char, 'Personagem');
    if v_delta > 0 and v_level >= v_max and coalesce(b->>'clockId','') <> ''
       and exists(select 1 from jsonb_array_elements(coalesce(st->'clocks','[]'::jsonb)) e where e->>'id' = b->>'clockId') then
      -- barra cheia com vínculo: avança o relógio e zera a barra (sem excedente)
      v_clock_id := b->>'clockId'; v_level := 0; v_stress_filled := true;
      v_logs := v_logs || jsonb_build_array(jsonb_build_object('icon','⚠','t','Estresse',
        'txt', format('%s — "%s" chegou ao limite e voltou a zero.', v_char, coalesce(b->>'name','Estresse')), 'vis', 'mestre'));
    end if;
    st := jsonb_set(st, array['stressBars', i::text], b || jsonb_build_object('level', v_level));
  end if;

  if v_clock_id is not null then
    select ord - 1, e into v_clk_idx, c from jsonb_array_elements(coalesce(st->'clocks','[]'::jsonb)) with ordinality as x(e, ord)
     where e->>'id' = v_clock_id limit 1;
    if c is null then raise exception 'not_found' using errcode = 'P0002'; end if;
    select * into r from public._ad_clock_step(c, case when p_op = 'stress' then 1 else v_delta end);
    st := jsonb_set(st, array['clocks', v_clk_idx::text], r.clk);
    if (r.clk->>'fill')::int <> coalesce(nullif(c->>'fill','')::int, 0) then
      v_logs := v_logs || jsonb_build_array(jsonb_build_object('icon','◷','t','Relógio',
        'txt', case when v_stress_filled then format('O estresse avançou "%s" (%s/%s).', r.clk->>'name', r.clk->>'fill', r.clk->>'seg')
                    when v_delta > 0 then format('"%s" avançou (%s/%s).', r.clk->>'name', r.clk->>'fill', r.clk->>'seg')
                    else format('"%s" recuou (%s/%s).', r.clk->>'name', r.clk->>'fill', r.clk->>'seg') end,
        'vis', case when r.clk->>'vis' = 'todos' then 'todos' when r.clk->>'vis' = 'jogador' then coalesce(r.clk->>'playerId','mestre') else 'mestre' end));
    end if;
    if r.completed then
      v_ev := jsonb_build_object('id', 'ev' || replace(gen_random_uuid()::text, '-', ''), 'clockId', r.clk->>'id',
        'name', r.clk->>'name', 'desc', coalesce(r.clk->>'desc', ''), 'type', r.clk->>'type', 'at', now(),
        'aud', case when r.clk->>'vis' = 'mestre' then 'mestre' when r.clk->>'vis' = 'jogador' then 'jogador' else 'todos' end,
        'playerId', r.clk->'playerId');
      v_events := v_events || jsonb_build_array(v_ev);
      v_logs := v_logs || jsonb_build_array(jsonb_build_object('icon','◷','t','Relógio',
        'txt', format('"%s" se completou.', r.clk->>'name'),
        'vis', case when r.clk->>'vis' = 'todos' then 'todos' when r.clk->>'vis' = 'jogador' then coalesce(r.clk->>'playerId','mestre') else 'mestre' end));
    end if;
  end if;

  -- histórico e eventos (mais recentes primeiro no log; eventos em ordem, últimos 40)
  select coalesce(jsonb_agg(l), '[]'::jsonb) into v_logs from (select l from jsonb_array_elements(v_logs) with ordinality as y(l, o) order by o desc) z;
  st := jsonb_set(st, '{log}', (v_logs || coalesce(st->'log','[]'::jsonb)));
  if jsonb_array_length(v_events) > 0 then
    st := jsonb_set(st, '{clockEvents}', (select coalesce(jsonb_agg(e order by o), '[]'::jsonb) from (
            select e, o from jsonb_array_elements(coalesce(st->'clockEvents','[]'::jsonb) || v_events) with ordinality as w(e, o)
            order by o desc limit 40) q));
  end if;

  update public.tables set session_state = st where id = p_table_id returning session_version into v_ver;
  insert into public._ad_session_ops(table_id, op_key) values (p_table_id, p_op_key);
  delete from public._ad_session_ops where table_id = p_table_id and created_at < now() - interval '2 days';
  return jsonb_build_object('ok', true, 'state', st, 'version', v_ver, 'events', v_events);
end $$;
revoke all on function public.master_clock_op(uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.master_clock_op(uuid, text, jsonb, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Penalidades (só o Mestre da mesa)
-- ---------------------------------------------------------------------------
create or replace function public.master_set_penalty(p_member_id uuid, p_op text, p_attr text, p_value int, p_reason text, p_id text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_table uuid; v_pen jsonb;
begin
  v_table := public._ad_member_table(p_member_id);
  if v_table is null or not public._ad_is_owner(v_table) then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_op not in ('add','remove') or p_id is null or length(p_id) < 4 or length(p_id) > 64 then
    raise exception 'invalid_request' using errcode = '22023';
  end if;
  select penalties into v_pen from public.table_members where id = p_member_id for update;
  v_pen := coalesce(v_pen, '[]'::jsonb);
  perform set_config('afterdark.trusted', 'on', true);
  if p_op = 'add' then
    if p_attr not in ('corpo','reflexo','mente','presenca','instinto','espirito') or p_value is null or p_value < 1 or p_value > 6 then
      raise exception 'invalid_request' using errcode = '22023';
    end if;
    if not exists(select 1 from jsonb_array_elements(v_pen) e where e->>'id' = p_id) then
      if jsonb_array_length(v_pen) >= 20 then raise exception 'too_many' using errcode = '22023'; end if;
      v_pen := v_pen || jsonb_build_array(jsonb_build_object('id', p_id, 'attr', p_attr, 'value', p_value,
        'reason', left(coalesce(p_reason, ''), 200), 'at', now()));
    end if;
  else
    select coalesce(jsonb_agg(e order by o), '[]'::jsonb) into v_pen
      from jsonb_array_elements(v_pen) with ordinality as x(e, o) where e->>'id' <> p_id;
  end if;
  update public.table_members set penalties = v_pen, updated_at = now() where id = p_member_id;
  return jsonb_build_object('ok', true, 'penalties', v_pen);
end $$;
revoke all on function public.master_set_penalty(uuid, text, text, int, text, text) from public, anon;
grant execute on function public.master_set_penalty(uuid, text, text, int, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Ciência do aviso de conclusão, por participante
-- ---------------------------------------------------------------------------
create or replace function public.player_ack_events(p_member_id uuid, p_token text, p_ids text[])
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_acked jsonb;
begin
  if not public._ad_member_ok(p_member_id, p_token) then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_ids is null or array_length(p_ids, 1) is null or array_length(p_ids, 1) > 40 then
    raise exception 'invalid_request' using errcode = '22023';
  end if;
  select acked_events into v_acked from public.table_members where id = p_member_id for update;
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb) into v_acked from (
    select x, min(o) as o from (
      select x, o from jsonb_array_elements_text(coalesce(v_acked,'[]'::jsonb)) with ordinality as a(x, o)
      union all select x, 1000000 + o from unnest(p_ids) with ordinality as b(x, o)
    ) u group by x order by min(o) desc limit 100) q;
  perform set_config('afterdark.trusted', 'on', true);
  update public.table_members set acked_events = v_acked where id = p_member_id;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.player_ack_events(uuid, text, text[]) from public;
grant execute on function public.player_ack_events(uuid, text, text[]) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Leituras do jogador: penalidades próprias; avisos de conclusão pendentes
-- ---------------------------------------------------------------------------
create or replace function public.player_get_state(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare m record; reqs jsonb; v_status text;
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select id, table_id, player_name, char_name, char_data, status, wounds, conditions, sheet_ready, approved_at,
         equipment, equip_rev, photo_rev, penalties
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
      'approved', m.approved_at is not null,
      'equipment', m.equipment, 'equip_rev', m.equip_rev, 'photo_rev', m.photo_rev,
      'penalties', m.penalties),
    'table_status', v_status,
    'requests', reqs);
end $$;
revoke all on function public.player_get_state(uuid, text) from public;
grant execute on function public.player_get_state(uuid, text) to anon, authenticated;

create or replace function public.player_get_session(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_table uuid; st jsonb; mid text;
  v_clocks jsonb; v_clock_ids text[]; v_stress jsonb;
  v_scene jsonb; v_active jsonb; v_pcs jsonb; v_npcs jsonb; v_unknown int;
  v_joined timestamptz; v_acked jsonb; v_events jsonb;
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  v_table := public._ad_member_table(p_member_id);
  if v_table is null then raise exception 'not_authorized' using errcode = '42501'; end if;
  mid := p_member_id::text;
  select coalesce(session_state, '{}'::jsonb) into st from public.tables where id = v_table;
  if st is null or st = '{}'::jsonb then return '{}'::jsonb; end if;

  -- Relógios: os da mesa visíveis, mais os dirigidos a este jogador.
  -- vis='mestre' cobre visMode mestre/avancar/completar antes do gatilho disparar.
  select coalesce(jsonb_agg(c - 'notes' order by ord), '[]'::jsonb) into v_clocks
    from jsonb_array_elements(coalesce(st->'clocks','[]'::jsonb)) with ordinality as e(c, ord)
   where c->>'vis' = 'todos'
      or (c->>'vis' = 'jogador' and c->>'playerId' = mid);

  -- Ids dos relógios que ESTE jogador pode ver, para limpar os vínculos abaixo.
  select coalesce(array_agg(x->>'id'), '{}'::text[]) into v_clock_ids
    from jsonb_array_elements(v_clocks) as x;

  select coalesce(jsonb_agg(
           case when coalesce(b->>'clockId','') = '' or (b->>'clockId') = any(v_clock_ids)
                then b
                else b - 'clockId'
           end order by ord), '[]'::jsonb) into v_stress
    from jsonb_array_elements(coalesce(st->'stressBars','[]'::jsonb)) with ordinality as e(b, ord)
   where coalesce(b->>'vis','titular') = 'todos'
      or (coalesce(b->>'vis','titular') = 'titular' and coalesce(b->>'playerId','') = mid);

  -- Cena ativa: só se o Mestre a compartilhou. Notas privadas nunca saem. Presentes:
  -- participantes da mesa e NPCs JÁ revelados (reveal >= 3); os não revelados viram só
  -- uma contagem ("figura não identificada"), sem id nem nome.
  select s into v_scene from jsonb_array_elements(coalesce(st->'scenes','[]'::jsonb)) s
   where s->>'id' = st->>'activeSceneId' limit 1;
  if v_scene is not null and coalesce((v_scene->>'shared')::boolean, false) then
    select coalesce(jsonb_agg(p->>'id'), '[]'::jsonb) into v_pcs
      from jsonb_array_elements(coalesce(v_scene->'present','[]'::jsonb)) p
     where p->>'kind' = 'pc' and exists(select 1 from public.table_members m where m.table_id = v_table and m.id::text = p->>'id');
    select coalesce(jsonb_agg(p->>'id'), '[]'::jsonb) into v_npcs
      from jsonb_array_elements(coalesce(v_scene->'present','[]'::jsonb)) p
     where p->>'kind' = 'npc' and exists(select 1 from jsonb_array_elements(coalesce(st->'npcs','[]'::jsonb)) n
                                          where n->>'id' = p->>'id' and coalesce((n->>'reveal')::int,1) >= 3);
    select count(*) into v_unknown
      from jsonb_array_elements(coalesce(v_scene->'present','[]'::jsonb)) p
     where p->>'kind' = 'npc' and exists(select 1 from jsonb_array_elements(coalesce(st->'npcs','[]'::jsonb)) n
                                          where n->>'id' = p->>'id' and coalesce((n->>'reveal')::int,1) < 3);
    v_active := jsonb_build_object('id', v_scene->'id', 'title', v_scene->'title', 'desc', v_scene->'desc',
      'mapId', v_scene->'mapId', 'presentPcs', v_pcs, 'presentNpcs', v_npcs, 'presentUnknown', v_unknown);
  end if;

  -- Avisos de conclusão destinados a este participante e ainda não confirmados por ele.
  -- "Só mestre" (aud = mestre) nunca sai. Eventos anteriores à entrada na mesa também não.
  select joined_at, coalesce(acked_events, '[]'::jsonb) into v_joined, v_acked from public.table_members where id = p_member_id;
  select coalesce(jsonb_agg(jsonb_build_object('id', e->'id', 'clockId', e->'clockId', 'name', e->'name', 'desc', e->'desc',
           'type', e->'type', 'at', e->'at') order by ord), '[]'::jsonb) into v_events
    from jsonb_array_elements(coalesce(st->'clockEvents','[]'::jsonb)) with ordinality as x(e, ord)
   where (e->>'aud' = 'todos' or (e->>'aud' = 'jogador' and e->>'playerId' = mid))
     and coalesce((e->>'at')::timestamptz, now()) >= v_joined
     and not (v_acked ? (e->>'id'));

  return jsonb_build_object(
    'activeScene', v_active,
    'clockEvents', v_events,
    'clocks', v_clocks,
    'stressBars', v_stress,

    -- NPCs: só os revelados ao grupo (reveal >= 3).
    'npcs', coalesce((
      select jsonb_agg(n - 'notes' order by ord)
      from jsonb_array_elements(coalesce(st->'npcs','[]'::jsonb)) with ordinality as e(n, ord)
      where coalesce((n->>'reveal')::int, 1) >= 3
    ), '[]'::jsonb),

    -- pistas: tudo que não está oculto
    'clues', coalesce((
      select jsonb_agg(k - 'notes' order by ord)
      from jsonb_array_elements(coalesce(st->'clues','[]'::jsonb)) with ordinality as e(k, ord)
      where coalesce(k->>'status', 'oculta') <> 'oculta'
    ), '[]'::jsonb),

    -- log: só o que é da mesa ou dirigido a este jogador. Sem "vis" fica com o Mestre.
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
revoke all on function public.player_get_session(uuid, text) from public;
grant execute on function public.player_get_session(uuid, text) to anon, authenticated;
