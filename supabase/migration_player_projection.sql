-- Afterdark — migração: projeção do jogador (estresse, vínculo de relógio e grupo)
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_rls_p2.sql (Ponto 2).
--
-- Reescreve player_get_session para que o jogador receba:
--
--   a) Barras de estresse por VISIBILIDADE, não por titularidade:
--        'todos'    -> a mesa inteira vê
--        'titular'  -> só o dono da barra (e o Mestre)
--        'mestre'   -> nenhum jogador vê
--      Barra antiga sem o campo "vis" assume 'titular' — padrão conservador: nada
--      que o Mestre não marcou como público passa a aparecer para a mesa.
--      MUDANÇA DE COMPORTAMENTO: antes, barra sem titular (playerId vazio) era
--      tratada como "da mesa". Agora ela só aparece se o Mestre marcar 'todos'.
--
--   b) O vínculo com relógio REMOVIDO quando o relógio não é visível a ele. Antes,
--      a barra carregava o clockId de um relógio oculto do Mestre: o nome não
--      aparecia na tela, mas o identificador chegava ao navegador do jogador.
--
-- Relógios seguem o mesmo filtro do Ponto 2 ('todos', ou 'jogador' dirigido a ele);
-- a lista agora é calculada uma vez e reaproveitada para limpar as barras.
--
--   c) player_get_lobby passa a devolver, dos ferimentos dos colegas, apenas id e
--      nível (a gravidade). A descrição é escrita pelo Mestre e pode ser narrativa
--      reservada — "Costela trincada" é categoria, mas um texto livre não é. O
--      jogador continua vendo a própria ficha inteira por player_get_state, então
--      nada se perde para o titular.

create or replace function public.player_get_session(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_table uuid; st jsonb; mid text;
  v_clocks jsonb; v_clock_ids text[]; v_stress jsonb;
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

  return jsonb_build_object(
    'clocks', v_clocks,
    'stressBars', v_stress,

    -- NPCs: só os revelados ao grupo (reveal >= 3).
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

-- ---------------------------------------------------------------------------
-- Visão pública dos membros: gravidade do ferimento, sem a descrição do Mestre
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
      -- só id e nível: "desc", "at" e "op" ficam fora da visão compartilhada
      'wounds', coalesce((
        select jsonb_agg(jsonb_build_object('id', w->'id', 'lvl', w->'lvl') order by ord)
        from jsonb_array_elements(m.wounds) with ordinality as e(w, ord)), '[]'::jsonb),
      'conditions', m.conditions,
      'sheet_ready', m.sheet_ready,
      'approved_at', m.approved_at
    ) order by m.joined_at), '[]'::jsonb) into v_members
    from public.table_members m where m.table_id = v_table;
  return jsonb_build_object('table_status', v_status, 'members', v_members);
end $$;

revoke all on function public.player_get_lobby(uuid, text) from public;
grant execute on function public.player_get_lobby(uuid, text) to anon, authenticated;
