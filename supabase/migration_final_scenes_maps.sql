-- Afterdark — migração (Plano final, Etapa 4): cenas e mapas como cadastros distintos.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_final_clocks.sql.
--
-- A cena (visão narrativa) ganha imagem própria (imageId, do acervo do Mestre) e o mapa
-- (planta) passa a ter seleção independente: session_state.activeMapId. A cena pode
-- apontar para um mapa (mapId) e, ao ser ativada, leva a esse mapa; sem mapa associado, o
-- mapa escolhido pelo Mestre continua. player_get_session entrega activeMapId e a imagem
-- da cena ativa compartilhada (a imagem em si sai por player_media, Etapa 2).
--
-- Dados existentes: nada é apagado. O app adota, ao abrir a mesa, o mapa da cena ativa como
-- mapa ativo quando ainda não há um.
--
-- Ordem: aplicar ANTES do deploy.

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
      'mapId', v_scene->'mapId', 'imageId', v_scene->'imageId', 'presentPcs', v_pcs, 'presentNpcs', v_npcs, 'presentUnknown', v_unknown);
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
    -- mapa ativo: independente da cena (Plano final, Etapa 4); só o id do catálogo público
    'activeMapId', st->'activeMapId',
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
