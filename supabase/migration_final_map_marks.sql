-- Afterdark — migração (Plano final, Etapa 5): marcações compartilhadas no mapa.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_final_scenes_maps.sql.
--
-- Cada marcação é um REGISTRO próprio (não o mapa inteiro), por mesa e mapa:
--   pc    -> posição do personagem de um participante (um por participante e mapa)
--   npc   -> NPC cadastrado posicionado pelo Mestre
--   point -> ponto do Mestre (porta, local, obstáculo, interesse) com nome/descrição
--   route -> rota do Mestre (pontos conectados), só orientação visual
-- Coordenadas normalizadas de 0 a 1, relativas à imagem do mapa: o mesmo ponto em qualquer
-- tela ou zoom. Zoom e câmera NÃO são gravados (são de cada pessoa).
-- Escrita:
--   * jogador: só move o PRÓPRIO marcador (player_mark_move), só no mapa ativo e com a mesa
--     viva (pausa bloqueia: decisão de 09/10/2026). Participante removido perde o acesso
--     (o token deixa de valer; as marcações dele somem junto).
--   * Mestre: cria/edita/remove qualquer marcação, define público/privado, limpa um mapa
--     (confirmação no app). Limpar não apaga NPC, ficha nem imagem.
--   * Operações repetíveis: o id da marcação vem do app; repetir é idempotente. Cada
--     registro tem rev própria: duas pessoas mexendo em marcações diferentes não se apagam.
-- Leitura: o jogador recebe, em player_get_session, as marcações públicas e os marcadores
-- de personagem do mapa ativo; privadas nunca saem. O Mestre lê tudo por master_marks.
--
-- Ordem: aplicar ANTES do deploy.

create table if not exists public.map_marks (
  id uuid primary key,
  table_id uuid not null references public.tables(id) on delete cascade,
  map_id text not null,
  kind text not null check (kind in ('pc','npc','point','route')),
  member_id uuid references public.table_members(id) on delete cascade,
  npc_id text,
  label text not null default '',
  descr text not null default '',
  icon text,
  x real, y real,
  points jsonb,
  visibility text not null default 'public' check (visibility in ('public','private')),
  rev integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists map_marks_one_pc on public.map_marks(table_id, map_id, member_id) where kind = 'pc';
create index if not exists map_marks_table_map on public.map_marks(table_id, map_id);
alter table public.map_marks enable row level security;
revoke all on public.map_marks from public, anon, authenticated;

create or replace function public._ad_mark_json(k public.map_marks)
returns jsonb language sql immutable set search_path = public as $$
  select jsonb_strip_nulls(jsonb_build_object('id', k.id, 'mapId', k.map_id, 'kind', k.kind, 'memberId', k.member_id,
    'npcId', k.npc_id, 'label', k.label, 'descr', nullif(k.descr,''), 'icon', k.icon, 'x', k.x, 'y', k.y,
    'points', k.points, 'visibility', k.visibility, 'rev', k.rev));
$$;
revoke all on function public._ad_mark_json(public.map_marks) from public, anon, authenticated;

create or replace function public._ad_xy_ok(x real, y real) returns boolean language sql immutable as $$
  select x is not null and y is not null and x >= 0 and x <= 1 and y >= 0 and y <= 1;
$$;

-- jogador: move o próprio marcador no mapa ativo
create or replace function public.player_mark_move(p_member_id uuid, p_token text, p_map_id text, p_x real, p_y real)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_table uuid; v_active text; v_char text; k public.map_marks;
begin
  if not public._ad_member_ok(p_member_id, p_token) then raise exception 'not_authorized' using errcode = '42501'; end if;
  v_table := public._ad_member_table(p_member_id);
  if not public._ad_table_live(v_table) then raise exception 'table_paused' using errcode = 'P0001'; end if;
  select session_state->>'activeMapId' into v_active from public.tables where id = v_table;
  if v_active is null or v_active <> p_map_id then raise exception 'map_not_active' using errcode = 'P0001'; end if;
  if not public._ad_xy_ok(p_x, p_y) then raise exception 'invalid_request' using errcode = '22023'; end if;
  select coalesce(nullif(char_name,''), nullif(player_name,''), 'Personagem') into v_char from public.table_members where id = p_member_id;
  insert into public.map_marks(id, table_id, map_id, kind, member_id, label, x, y)
    values (gen_random_uuid(), v_table, p_map_id, 'pc', p_member_id, left(v_char, 60), p_x, p_y)
  on conflict (table_id, map_id, member_id) where kind = 'pc'
    do update set x = excluded.x, y = excluded.y, label = excluded.label, rev = map_marks.rev + 1, updated_at = now()
  returning * into k;
  return jsonb_build_object('ok', true, 'mark', public._ad_mark_json(k));
end $$;
revoke all on function public.player_mark_move(uuid, text, text, real, real) from public;
grant execute on function public.player_mark_move(uuid, text, text, real, real) to anon, authenticated;

-- Mestre: cria ou altera uma marcação (id vindo do app; repetir é idempotente)
create or replace function public.master_mark_upsert(p_table_id uuid, p_mark jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_kind text; v_x real; v_y real; v_pts jsonb; v_mem uuid; k public.map_marks; v_vis text;
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  begin v_id := (p_mark->>'id')::uuid; exception when others then raise exception 'invalid_request' using errcode = '22023'; end;
  v_kind := p_mark->>'kind'; v_x := (p_mark->>'x')::real; v_y := (p_mark->>'y')::real; v_pts := p_mark->'points';
  v_vis := coalesce(p_mark->>'visibility','public');
  if v_id is null or v_kind not in ('pc','npc','point','route') or coalesce(p_mark->>'mapId','') = ''
     or v_vis not in ('public','private') then raise exception 'invalid_request' using errcode = '22023'; end if;
  if v_kind = 'route' then
    if jsonb_typeof(v_pts) <> 'array' or jsonb_array_length(v_pts) < 2 or jsonb_array_length(v_pts) > 60
       or exists(select 1 from jsonb_array_elements(v_pts) p where not public._ad_xy_ok((p->>0)::real, (p->>1)::real)) then
      raise exception 'invalid_request' using errcode = '22023'; end if;
  elsif not public._ad_xy_ok(v_x, v_y) then raise exception 'invalid_request' using errcode = '22023';
  end if;
  if v_kind = 'pc' then
    v_mem := (p_mark->>'memberId')::uuid;
    if not exists(select 1 from public.table_members where id = v_mem and table_id = p_table_id) then raise exception 'invalid_request' using errcode = '22023'; end if;
    v_vis := 'public';
  end if;
  select * into k from public.map_marks where id = v_id;
  if found and k.table_id <> p_table_id then raise exception 'not_authorized' using errcode = '42501'; end if;
  if v_kind = 'pc' and not found then
    -- marcador de personagem: um por participante e mapa (Mestre reposiciona o existente)
    select * into k from public.map_marks where table_id = p_table_id and map_id = p_mark->>'mapId' and member_id = v_mem and kind = 'pc';
    if found then v_id := k.id; end if;
  end if;
  insert into public.map_marks(id, table_id, map_id, kind, member_id, npc_id, label, descr, icon, x, y, points, visibility)
    values (v_id, p_table_id, p_mark->>'mapId', v_kind, v_mem, left(p_mark->>'npcId',40), left(coalesce(p_mark->>'label',''),60),
            left(coalesce(p_mark->>'descr',''),300), left(p_mark->>'icon',20), case when v_kind = 'route' then null else v_x end,
            case when v_kind = 'route' then null else v_y end, case when v_kind = 'route' then v_pts end, v_vis)
  on conflict (id) do update set label = excluded.label, descr = excluded.descr, icon = excluded.icon, npc_id = excluded.npc_id,
    x = excluded.x, y = excluded.y, points = excluded.points, visibility = excluded.visibility,
    rev = map_marks.rev + 1, updated_at = now()
  returning * into k;
  return jsonb_build_object('ok', true, 'mark', public._ad_mark_json(k));
end $$;
revoke all on function public.master_mark_upsert(uuid, jsonb) from public, anon;
grant execute on function public.master_mark_upsert(uuid, jsonb) to authenticated;

create or replace function public.master_mark_delete(p_table_id uuid, p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  delete from public.map_marks where id = p_id and table_id = p_table_id;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function public.master_mark_delete(uuid, uuid) from public, anon;
grant execute on function public.master_mark_delete(uuid, uuid) to authenticated;

create or replace function public.master_mark_clear(p_table_id uuid, p_map_id text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  delete from public.map_marks where table_id = p_table_id and map_id = p_map_id;
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'removed', n);
end $$;
revoke all on function public.master_mark_clear(uuid, text) from public, anon;
grant execute on function public.master_mark_clear(uuid, text) to authenticated;

create or replace function public.master_marks(p_table_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  return coalesce((select jsonb_agg(public._ad_mark_json(k) order by k.created_at) from public.map_marks k where k.table_id = p_table_id), '[]'::jsonb);
end $$;
revoke all on function public.master_marks(uuid) from public, anon;
grant execute on function public.master_marks(uuid) to authenticated;

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
    -- marcações do mapa ativo: públicas + marcadores de personagens (Etapa 5)
    'marks', coalesce((select jsonb_agg(public._ad_mark_json(k) order by k.created_at)
       from public.map_marks k where k.table_id = v_table and k.map_id = st->>'activeMapId'
        and (k.visibility = 'public' or k.kind = 'pc')), '[]'::jsonb),
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
