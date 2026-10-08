-- Afterdark — migração (Pós-sessão, Etapa 2): NPCs, pistas, cenas e mapas.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_equipment_photo.sql (Etapa 1).
--
-- O Mestre passa a cadastrar NPCs (nome, descrição, notas privadas), pistas (título,
-- conteúdo, notas privadas) e cenas (título, descrição, notas privadas, presentes, mapa,
-- compartilhamento). Tudo continua no estado da sessão (session_state), gravado só pelo
-- Mestre (master_save_session). Esta migração muda apenas o que o JOGADOR recebe:
--   * npcs e clues saem SEM o campo "notes" (notas privadas do Mestre);
--   * "scenes" (a lista de cenas) e "activeSceneId" não saem;
--   * "activeScene": a cena ativa, só quando compartilhada, sem notas, com os presentes
--     filtrados (participantes da mesa e NPCs revelados; não revelados só como contagem).
--
-- Ordem: aplicar ANTES do deploy. O cliente antigo funciona com ela (ignora activeScene);
-- já o cliente novo sem ela mandaria aos jogadores as notas privadas que ele cria.

create or replace function public.player_get_session(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_table uuid; st jsonb; mid text;
  v_clocks jsonb; v_clock_ids text[]; v_stress jsonb;
  v_scene jsonb; v_active jsonb; v_pcs jsonb; v_npcs jsonb; v_unknown int;
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
  select coalesce(jsonb_agg(c order by ord), '[]'::jsonb) into v_clocks
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

  return jsonb_build_object(
    'activeScene', v_active,
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
