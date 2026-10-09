-- Afterdark — migração (Plano final, Etapa 1): pausa bloqueia as ações da mesa.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_clocks_stress.sql.
--
-- Decisão de 09/10/2026: com a mesa pausada (ou encerrada), qualquer ação do JOGADOR que
-- mexa na mesa fica bloqueada também no banco: responder teste e pegar/largar
-- equipamento. Menu, perfil, personagens, mesas, ficha e foto continuam livres. O Mestre
-- não é afetado. (Marcações no mapa, da Etapa 5, seguem a mesma regra.)
--
-- Ordem: livre. O cliente antigo só passa a receber 'table_paused' nessas ações.

create or replace function public._ad_table_live(p_table_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  -- viva = existe e não está pausada nem encerrada (o lobby continua liberado)
  select coalesce((select status not like 'Pausada%' and status <> 'Encerrada' from public.tables where id = p_table_id), false);
$$;
revoke all on function public._ad_table_live(uuid) from public, anon, authenticated;

create or replace function public.player_answer_request(p_member_id uuid, p_token text, p_request_id uuid, p_result jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r record;
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  if p_result is null or jsonb_typeof(p_result) <> 'object' or pg_column_size(p_result) > 16000 then
    raise exception 'invalid_result' using errcode = '22023';
  end if;
  -- Etapa 1 (plano final): com a mesa pausada ou encerrada, o jogador nao responde testes.
  -- Reenvio de resposta ja gravada continua idempotente (verificado abaixo).
  if not public._ad_table_live(public._ad_member_table(p_member_id))
     and exists(select 1 from public.table_requests where id = p_request_id and target_member_id = p_member_id and status = 'pendente') then
    raise exception 'table_paused' using errcode = 'P0001';
  end if;
  update public.table_requests set status = 'respondido', result = p_result, answered_at = now()
    where id = p_request_id and target_member_id = p_member_id and status = 'pendente'
    returning id, status into r;
  if found then return jsonb_build_object('ok', true, 'duplicate', false); end if;
  select id, status into r from public.table_requests where id = p_request_id and target_member_id = p_member_id;
  if not found then raise exception 'request_not_found' using errcode = 'P0002'; end if;
  if r.status = 'respondido' then return jsonb_build_object('ok', true, 'duplicate', true); end if;
  raise exception 'request_cancelled' using errcode = 'P0001';
end $$;
revoke all on function public.player_answer_request(uuid, text, uuid, jsonb) from public;
grant execute on function public.player_answer_request(uuid, text, uuid, jsonb) to anon, authenticated;

create or replace function public.member_equip(p_member_id uuid, p_token text, p_op text,
  p_kind text, p_ref text, p_iid text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_actor text; v_table uuid; m record; v_item jsonb; v_eq jsonb; v_rev int;
begin
  v_actor := public._ad_member_actor(p_member_id, p_token);
  if v_actor is null then raise exception 'not_authorized' using errcode = '42501'; end if;
  -- Etapa 1 (plano final): pausa bloqueia a acao do jogador; o Mestre continua podendo ajustar.
  if v_actor = 'jogador' and not public._ad_table_live(public._ad_member_table(p_member_id)) then
    raise exception 'table_paused' using errcode = 'P0001';
  end if;
  if p_op not in ('add','remove') or p_kind not in ('weapons','items')
     or p_iid is null or length(p_iid) < 8 or length(p_iid) > 64 then
    raise exception 'invalid_request' using errcode = '22023';
  end if;
  -- trava a linha: duas operações simultâneas no mesmo personagem não se perdem
  select id, table_id, equipment, equip_rev into m from public.table_members where id = p_member_id for update;
  v_eq := coalesce(m.equipment, '[]'::jsonb);
  perform set_config('afterdark.trusted', 'on', true);

  if p_op = 'add' then
    if exists(select 1 from jsonb_array_elements(v_eq) e where e->>'iid' = p_iid) then
      return jsonb_build_object('ok', true, 'equipment', v_eq, 'rev', m.equip_rev, 'dup', true);
    end if;
    if jsonb_array_length(v_eq) >= 60 then raise exception 'equipment_full' using errcode = '22023'; end if;
    select e into v_item
      from public.tables t, jsonb_array_elements(coalesce(t.session_state->'library'->p_kind, '[]'::jsonb)) e
     where t.id = m.table_id and e->>'id' = p_ref limit 1;
    if v_item is null then raise exception 'not_in_catalog' using errcode = 'P0002'; end if;
    v_eq := v_eq || jsonb_build_array(jsonb_strip_nulls(jsonb_build_object(
      'iid', p_iid, 'kind', p_kind, 'ref', p_ref,
      'name', left(coalesce(v_item->>'name', 'Item'), 80),
      'desc', left(v_item->>'desc', 400),
      'bonus', v_item->'bonus', 'dano', v_item->'dano',
      'alcance', v_item->'alcance', 'ruido', v_item->'ruido',
      'by', v_actor, 'at', now())));
  else
    if not exists(select 1 from jsonb_array_elements(v_eq) e where e->>'iid' = p_iid) then
      return jsonb_build_object('ok', true, 'equipment', v_eq, 'rev', m.equip_rev, 'dup', true);
    end if;
    select coalesce(jsonb_agg(e order by ord), '[]'::jsonb) into v_eq
      from jsonb_array_elements(v_eq) with ordinality as x(e, ord) where e->>'iid' <> p_iid;
  end if;

  update public.table_members set equipment = v_eq, equip_rev = equip_rev + 1, updated_at = now()
   where id = p_member_id returning equip_rev into v_rev;
  return jsonb_build_object('ok', true, 'equipment', v_eq, 'rev', v_rev);
end $$;
revoke all on function public.member_equip(uuid, text, text, text, text, text) from public;
grant execute on function public.member_equip(uuid, text, text, text, text, text) to anon, authenticated;
