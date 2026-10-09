-- Afterdark — migração (Plano final, Etapa 3): aviso de relógio revelado, imagem do aviso
-- de conclusão e retenção dos avisos.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_final_media.sql.
--
--   * master_clock_op passa a gerar o evento 'reveal' quando um avanço (manual ou por
--     estresse) revela o relógio sem completá-lo (Parcial na metade, Ao avançar no
--     primeiro avanço). A conclusão continua gerando 'complete', que já comunica a
--     revelação: um aviso só. Relógio "Só mestre" continua sem aviso aos jogadores.
--   * O aviso guarda o conteúdo do momento (título, descrição, progresso e imageId da
--     "Imagem da conclusão" do relógio). Editar o relógio depois não muda o aviso pendente.
--   * Retenção: avisos dos últimos 14 dias (teto 300 por mesa), em vez dos 40 últimos.
--   * player_get_session entrega kind, progresso e imageId; a imagem só é lida por
--     player_media se o aviso for destinado ao participante (já previsto na Etapa 2).
--
-- Ordem: aplicar ANTES do deploy.

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
    -- Plano final, Etapa 3: revelação sem conclusão gera aviso próprio ("Relógio revelado");
    -- a conclusão já comunica a revelação (um aviso só). O aviso guarda título, descrição,
    -- progresso e imagem DAQUELE momento: editar o relógio depois não muda o aviso pendente.
    if r.revealed and not r.completed then
      v_events := v_events || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
        'id', 'ev' || replace(gen_random_uuid()::text, '-', ''), 'kind', 'reveal', 'clockId', r.clk->>'id',
        'name', r.clk->>'name', 'type', r.clk->>'type', 'at', now(),
        'fill', (r.clk->>'fill')::int, 'seg', (r.clk->>'seg')::int,
        'aud', case when r.clk->>'vis' = 'jogador' then 'jogador' else 'todos' end,
        'playerId', r.clk->'playerId')));
    end if;
    if r.completed then
      v_ev := jsonb_build_object('id', 'ev' || replace(gen_random_uuid()::text, '-', ''), 'kind', 'complete', 'clockId', r.clk->>'id',
        'imageId', nullif(r.clk->>'imageId',''),
        'fill', (r.clk->>'fill')::int, 'seg', (r.clk->>'seg')::int,
        'name', r.clk->>'name', 'desc', coalesce(r.clk->>'desc', ''), 'type', r.clk->>'type', 'at', now(),
        'aud', case when r.clk->>'vis' = 'mestre' then 'mestre' when r.clk->>'vis' = 'jogador' then 'jogador' else 'todos' end,
        'playerId', r.clk->'playerId');
      v_events := v_events || jsonb_build_array(jsonb_strip_nulls(v_ev));
      v_logs := v_logs || jsonb_build_array(jsonb_build_object('icon','◷','t','Relógio',
        'txt', format('"%s" se completou.', r.clk->>'name'),
        'vis', case when r.clk->>'vis' = 'todos' then 'todos' when r.clk->>'vis' = 'jogador' then coalesce(r.clk->>'playerId','mestre') else 'mestre' end));
    end if;
  end if;

  -- histórico e eventos (mais recentes primeiro no log). Avisos: retenção de 14 dias
  -- (decisão de 09/10/2026), com teto de 300 por mesa, para não descartar o aviso de
  -- quem ficou fora (antes: só os 40 últimos).
  select coalesce(jsonb_agg(l), '[]'::jsonb) into v_logs from (select l from jsonb_array_elements(v_logs) with ordinality as y(l, o) order by o desc) z;
  st := jsonb_set(st, '{log}', (v_logs || coalesce(st->'log','[]'::jsonb)));
  if jsonb_array_length(v_events) > 0 then
    st := jsonb_set(st, '{clockEvents}', (select coalesce(jsonb_agg(e order by o), '[]'::jsonb) from (
            select e, o from jsonb_array_elements(coalesce(st->'clockEvents','[]'::jsonb) || v_events) with ordinality as w(e, o)
             where coalesce((e->>'at')::timestamptz, now()) > now() - interval '14 days'
            order by o desc limit 300) q));
  end if;

  update public.tables set session_state = st where id = p_table_id returning session_version into v_ver;
  insert into public._ad_session_ops(table_id, op_key) values (p_table_id, p_op_key);
  delete from public._ad_session_ops where table_id = p_table_id and created_at < now() - interval '2 days';
  return jsonb_build_object('ok', true, 'state', st, 'version', v_ver, 'events', v_events);
end $$;
revoke all on function public.master_clock_op(uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.master_clock_op(uuid, text, jsonb, uuid) to authenticated;

create or replace function public.player_get_session(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_table uuid; st jsonb; mid text;
  v_clocks jsonb; v_clock_ids text[]; v_stress jsonb;
  v_scene jsonb; v_active jsonb; v_pcs jsonb; v_npcs jsonb; v_unknown int;
  v_joined timestamptz; v_acked jsonb; v_events jsonb; v_dlg jsonb;
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
  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('id', e->'id', 'kind', coalesce(e->'kind', '"complete"'::jsonb),
           'clockId', e->'clockId', 'name', e->'name', 'desc', e->'desc', 'type', e->'type', 'at', e->'at',
           'fill', e->'fill', 'seg', e->'seg', 'imageId', e->'imageId')) order by ord), '[]'::jsonb) into v_events
    from jsonb_array_elements(coalesce(st->'clockEvents','[]'::jsonb)) with ordinality as x(e, ord)
   where (e->>'aud' = 'todos' or (e->>'aud' = 'jogador' and e->>'playerId' = mid))
     and coalesce((e->>'at')::timestamptz, now()) >= v_joined
     and coalesce((e->>'at')::timestamptz, now()) > now() - interval '14 days'
     and not (v_acked ? (e->>'id'));

  -- NPC em diálogo (Plano final, Etapa 2): nome e texto públicos; imagem só com o retrato
  -- revelado (nível 4). Notas nunca saem.
  select jsonb_strip_nulls(jsonb_build_object('id', n->'id', 'name', n->'name', 'desc', n->'desc', 'faction', n->'faction',
           'theme', n->'theme', 'reveal', n->'reveal',
           'imageId', case when coalesce((n->>'reveal')::int,1) >= 4 then n->'imageId' end,
           'imageFit', case when coalesce((n->>'reveal')::int,1) >= 4 then n->'imageFit' end))
    into v_dlg
    from jsonb_array_elements(coalesce(st->'npcs','[]'::jsonb)) n
   where n->>'id' = st->>'activeNpcId' limit 1;

  return jsonb_build_object(
    'activeScene', v_active,
    'dialogue', v_dlg,
    'clockEvents', v_events,
    'clocks', v_clocks,
    'stressBars', v_stress,

    -- NPCs: só os revelados ao grupo (reveal >= 3).
    'npcs', coalesce((
      select jsonb_agg(case when coalesce((n->>'reveal')::int,1) >= 4 then n - 'notes' else n - 'notes' - 'imageId' - 'imageFit' end order by ord)
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
