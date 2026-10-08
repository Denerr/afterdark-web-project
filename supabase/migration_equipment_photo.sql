-- Afterdark — migração (Pós-sessão, Etapa 1): equipamento por personagem e foto na mesa.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_identity.sql (Etapa 0).
--
-- Equipamento. Antes, o "inventário" era UM só para a mesa inteira, dentro do estado da
-- sessão que só o Mestre grava. O jogador mudava a lista só na própria tela e a leitura
-- automática seguinte (2–3 s) devolvia a versão do banco: o item "voltava".
-- Agora cada participante tem o próprio equipamento (table_members.equipment), gravado
-- por member_equip. A biblioteca da mesa é um CATÁLOGO: cada atribuição cria um
-- exemplar com id próprio (iid) e uma cópia dos dados do item. Mestre e jogador podem
-- pegar/largar itens do personagem do jogador; só itens que o Mestre cadastrou no
-- catálogo (session_state.library) são aceitos. equip_rev cresce a cada mudança: o app
-- ignora leituras com revisão menor que a última confirmada.
--
-- Foto. A foto do personagem só existia no Perfil da conta e nunca chegava à mesa; o
-- Mestre a procurava pelo NOME do personagem nos personagens dele. Agora a foto da mesa
-- fica em table_members.photo (imagem reduzida pelo app, data URL de até ~200 KB),
-- gravada por member_set_photo. As leituras automáticas trazem só photo_rev; a imagem
-- vem por member_photos quando a revisão muda.
--
-- Ordem: aplicar ESTA migração antes de publicar o index.html da Etapa 1. O cliente
-- antigo continua funcionando com o banco novo (as funções antigas não mudam de
-- assinatura; player_get_state e player_get_lobby só ganham campos).

alter table public.table_members
  add column if not exists equipment jsonb not null default '[]'::jsonb,
  add column if not exists equip_rev integer not null default 0,
  add column if not exists photo text,
  add column if not exists photo_rev integer not null default 0;

-- ---------------------------------------------------------------------------
-- Autorização comum: o próprio participante (token ou conta) ou o dono da mesa.
-- Devolve 'jogador', 'mestre' ou null.
-- ---------------------------------------------------------------------------
create or replace function public._ad_member_actor(p_member_id uuid, p_token text)
returns text language plpgsql stable security definer set search_path = public as $$
declare v_table uuid;
begin
  v_table := public._ad_member_table(p_member_id);
  if v_table is null then return null; end if;
  if public._ad_is_owner(v_table) then return 'mestre'; end if;
  if public._ad_member_ok(p_member_id, p_token) then return 'jogador'; end if;
  return null;
end $$;
revoke all on function public._ad_member_actor(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Equipamento: pegar (add) / largar (remove) um exemplar
--   p_kind: 'weapons' | 'items'; p_ref: id do item no catálogo da mesa;
--   p_iid: id do exemplar (gerado pelo app, uuid). Repetir a mesma operação não
--   duplica: add com iid existente e remove de iid ausente são no-op.
-- ---------------------------------------------------------------------------
create or replace function public.member_equip(p_member_id uuid, p_token text, p_op text,
  p_kind text, p_ref text, p_iid text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_actor text; v_table uuid; m record; v_item jsonb; v_eq jsonb; v_rev int;
begin
  v_actor := public._ad_member_actor(p_member_id, p_token);
  if v_actor is null then raise exception 'not_authorized' using errcode = '42501'; end if;
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

-- ---------------------------------------------------------------------------
-- Foto do personagem na mesa (definir ou remover). Só o próprio participante ou o Mestre.
-- ---------------------------------------------------------------------------
create or replace function public.member_set_photo(p_member_id uuid, p_token text, p_photo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_actor text; v_rev int;
begin
  v_actor := public._ad_member_actor(p_member_id, p_token);
  if v_actor is null then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_photo is not null then
    if length(p_photo) > 200000 then raise exception 'photo_too_large' using errcode = '22023'; end if;
    if p_photo !~ '^data:image/(jpeg|png|webp);base64,[A-Za-z0-9+/]+=*$' then
      raise exception 'photo_invalid' using errcode = '22023';
    end if;
  end if;
  perform set_config('afterdark.trusted', 'on', true);
  update public.table_members set photo = p_photo, photo_rev = photo_rev + 1, updated_at = now()
   where id = p_member_id returning photo_rev into v_rev;
  return jsonb_build_object('ok', true, 'rev', v_rev);
end $$;
revoke all on function public.member_set_photo(uuid, text, text) from public;
grant execute on function public.member_set_photo(uuid, text, text) to anon, authenticated;

-- Fotos dos participantes da mesa (o próprio vínculo autoriza; o Mestre também).
-- p_ids opcional: só esses membros (o app pede apenas os que mudaram de revisão).
create or replace function public.member_photos(p_member_id uuid, p_token text, p_ids uuid[] default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_table uuid;
begin
  if public._ad_member_actor(p_member_id, p_token) is null then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  v_table := public._ad_member_table(p_member_id);
  return coalesce((select jsonb_object_agg(m.id::text, jsonb_build_object('photo', m.photo, 'rev', m.photo_rev))
    from public.table_members m
   where m.table_id = v_table and (p_ids is null or m.id = any(p_ids))), '{}'::jsonb);
end $$;
revoke all on function public.member_photos(uuid, text, uuid[]) from public;
grant execute on function public.member_photos(uuid, text, uuid[]) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Leituras do jogador: o próprio equipamento e as revisões de foto
-- ---------------------------------------------------------------------------
create or replace function public.player_get_state(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare m record; reqs jsonb; v_status text;
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select id, table_id, player_name, char_name, char_data, status, wounds, conditions, sheet_ready, approved_at,
         equipment, equip_rev, photo_rev
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
      'equipment', m.equipment, 'equip_rev', m.equip_rev, 'photo_rev', m.photo_rev),
    'table_status', v_status,
    'requests', reqs);
end $$;
revoke all on function public.player_get_state(uuid, text) from public;
grant execute on function public.player_get_state(uuid, text) to anon, authenticated;

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
      'approved_at', m.approved_at,
      'photo_rev', m.photo_rev
    ) order by m.joined_at), '[]'::jsonb) into v_members
    from public.table_members m where m.table_id = v_table;
  return jsonb_build_object('table_status', v_status, 'members', v_members);
end $$;
revoke all on function public.player_get_lobby(uuid, text) from public;
grant execute on function public.player_get_lobby(uuid, text) to anon, authenticated;
