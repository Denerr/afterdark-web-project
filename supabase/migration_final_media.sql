-- Afterdark — migração (Plano final, Etapa 2): acervo de imagens, retratos de NPC e diálogo.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_final_pause.sql.
--
-- Imagens (decisão de 09/10/2026: tabela no banco, não Storage):
--   * public.media guarda cada imagem UMA vez (data URL já reduzida pelo app, até ~700 KB),
--     com id imutável. O estado da sessão guarda só o id, então a leitura a cada 2–3 s
--     não carrega imagem nenhuma; o app busca cada id uma vez e guarda em cache.
--   * O acervo é do Mestre (owner_id): imagens enviadas numa mesa ficam disponíveis para
--     reutilizar em outras.
--   * O Mestre lê as próprias imagens (master_media_get/list). O jogador só recebe uma imagem
--     por player_media, e só se ela estiver VISÍVEL para ele na mesa dele (retrato de NPC
--     revelado no nível 4, NPC em diálogo com retrato revelado, imagem da cena ativa
--     compartilhada e, na Etapa 3, imagem de aviso já entregue a ele). Silhueta e nome oculto
--     não revelam a imagem nem o id.
--
-- Diálogo: session_state.activeNpcId (gravado pelo Mestre) e a projeção 'dialogue' em
-- player_get_session (nome, descrição pública e imagem autorizada; nunca as notas).
--
-- Ordem: aplicar ANTES do deploy.

create table if not exists public.media (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null default 'other' check (kind in ('npc','scene','clock','other')),
  name text not null default '',
  data text not null,
  width int, height int,
  created_at timestamptz not null default now()
);
create index if not exists media_owner_idx on public.media(owner_id, created_at desc);
alter table public.media enable row level security;
revoke all on public.media from public, anon, authenticated;

create or replace function public.master_media_upload(p_kind text, p_name text, p_data text, p_width int, p_height int)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_kind not in ('npc','scene','clock','other') then raise exception 'invalid_request' using errcode = '22023'; end if;
  if p_data is null or length(p_data) > 700000 then raise exception 'media_too_large' using errcode = '22023'; end if;
  if p_data !~ '^data:image/(jpeg|png|webp);base64,[A-Za-z0-9+/]+=*$' then raise exception 'media_invalid' using errcode = '22023'; end if;
  if (select count(*) from public.media where owner_id = auth.uid()) >= 500 then raise exception 'media_quota' using errcode = '22023'; end if;
  insert into public.media(owner_id, kind, name, data, width, height)
    values (auth.uid(), p_kind, left(coalesce(p_name,''), 120), p_data, p_width, p_height) returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;
revoke all on function public.master_media_upload(text, text, text, int, int) from public, anon;
grant execute on function public.master_media_upload(text, text, text, int, int) to authenticated;

-- Acervo: lista sem o conteúdo (leve); filtra por tipo se informado
create or replace function public.master_media_list(p_kind text default null)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'name', name, 'width', width, 'height', height, 'created_at', created_at)
           order by created_at desc), '[]'::jsonb)
    from public.media where auth.uid() is not null and owner_id = auth.uid() and (p_kind is null or kind = p_kind);
$$;
revoke all on function public.master_media_list(text) from public, anon;
grant execute on function public.master_media_list(text) to authenticated;

create or replace function public.master_media_get(p_ids uuid[])
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(id::text, data), '{}'::jsonb)
    from public.media where auth.uid() is not null and owner_id = auth.uid() and id = any(coalesce(p_ids, '{}'::uuid[]));
$$;
revoke all on function public.master_media_get(uuid[]) from public, anon;
grant execute on function public.master_media_get(uuid[]) to authenticated;

create or replace function public.master_media_delete(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  delete from public.media where id = p_id and owner_id = auth.uid();
  return jsonb_build_object('ok', found);
end $$;
revoke all on function public.master_media_delete(uuid) from public, anon;
grant execute on function public.master_media_delete(uuid) to authenticated;

-- Ids de imagem que um participante pode ver agora (mesma regra da projeção)
create or replace function public._ad_visible_media(p_member_id uuid)
returns text[] language plpgsql stable security definer set search_path = public as $$
declare st jsonb; v_table uuid; mid text := p_member_id::text; out text[] := '{}'; v_scene jsonb; v_acked jsonb;
begin
  v_table := public._ad_member_table(p_member_id);
  select coalesce(session_state, '{}'::jsonb) into st from public.tables where id = v_table;
  -- retratos revelados (nível 4), inclusive o NPC em diálogo
  select coalesce(array_agg(n->>'imageId'), '{}') into out
    from jsonb_array_elements(coalesce(st->'npcs','[]'::jsonb)) n
   where coalesce((n->>'reveal')::int,1) >= 4 and coalesce(n->>'imageId','') <> '';
  -- imagem da cena ativa compartilhada
  select s into v_scene from jsonb_array_elements(coalesce(st->'scenes','[]'::jsonb)) s
   where s->>'id' = st->>'activeSceneId' limit 1;
  if v_scene is not null and coalesce((v_scene->>'shared')::boolean,false) and coalesce(v_scene->>'imageId','') <> '' then
    out := out || (v_scene->>'imageId');
  end if;
  -- imagens de avisos de relógio destinados a este participante (Etapa 3)
  out := out || coalesce((select array_agg(e->>'imageId')
    from jsonb_array_elements(coalesce(st->'clockEvents','[]'::jsonb)) e
   where coalesce(e->>'imageId','') <> '' and (e->>'aud' = 'todos' or (e->>'aud' = 'jogador' and e->>'playerId' = mid))), '{}');
  return out;
end $$;
revoke all on function public._ad_visible_media(uuid) from public, anon, authenticated;

create or replace function public.player_media(p_member_id uuid, p_token text, p_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_vis text[]; v_owner uuid;
begin
  if not public._ad_member_ok(p_member_id, p_token) then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_ids is null or array_length(p_ids,1) is null then return '{}'::jsonb; end if;
  if array_length(p_ids,1) > 30 then raise exception 'invalid_request' using errcode = '22023'; end if;
  v_vis := public._ad_visible_media(p_member_id);
  select owner_id into v_owner from public.tables where id = public._ad_member_table(p_member_id);
  return coalesce((select jsonb_object_agg(m.id::text, m.data) from public.media m
    where m.id = any(p_ids) and m.id::text = any(v_vis) and m.owner_id = v_owner), '{}'::jsonb);
end $$;
revoke all on function public.player_media(uuid, text, uuid[]) from public;
grant execute on function public.player_media(uuid, text, uuid[]) to anon, authenticated;

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
  select coalesce(jsonb_agg(jsonb_build_object('id', e->'id', 'clockId', e->'clockId', 'name', e->'name', 'desc', e->'desc',
           'type', e->'type', 'at', e->'at') order by ord), '[]'::jsonb) into v_events
    from jsonb_array_elements(coalesce(st->'clockEvents','[]'::jsonb)) with ordinality as x(e, ord)
   where (e->>'aud' = 'todos' or (e->>'aud' = 'jogador' and e->>'playerId' = mid))
     and coalesce((e->>'at')::timestamptz, now()) >= v_joined
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
