-- Afterdark — migração (Ponto 1): solicitações de teste, resultados, ferimentos,
-- condições, prontidão e aprovação persistidos por mesa/membro.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente: pode ser executada de novo sem duplicar objetos.
--
-- Identidade do jogador: cada membro recebe um TOKEN secreto ao entrar na mesa
-- (join_table_by_code). O banco guarda só o hash SHA-256 do token, numa tabela
-- sem acesso direto (table_member_secrets). Jogador logado também é aceito por
-- auth.uid() = user_id. Toda ação do jogador passa por funções que validam isso.
--
-- Transporte: POLLING (o app já sincroniza o lobby/sessão a cada 2–3 s). Realtime
-- exigiria RLS por auth.uid(), e visitantes ainda não têm identidade de auth —
-- a revisão disso fica para o Ponto 2. Os clientes encerram os intervals ao sair.
--
-- As tabelas novas NÃO têm policies para anon/authenticated além do dono da mesa:
-- jogadores só leem/escrevem via funções security definer.

-- ---------------------------------------------------------------------------
-- 1) Colunas novas em table_members (fonte de verdade das consequências)
-- ---------------------------------------------------------------------------
alter table public.table_members
  add column if not exists wounds jsonb not null default '[]'::jsonb,
  add column if not exists conditions jsonb not null default '[]'::jsonb,
  add column if not exists sheet_ready boolean not null default false,
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references auth.users(id) on delete set null;

-- ---------------------------------------------------------------------------
-- 2) Segredo por membro (hash do token) — sem nenhuma policy: inacessível via API
-- ---------------------------------------------------------------------------
create table if not exists public.table_member_secrets (
  member_id uuid primary key references public.table_members(id) on delete cascade,
  token_hash text not null,
  created_at timestamptz not null default now()
);
alter table public.table_member_secrets enable row level security;
revoke all on public.table_member_secrets from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) Solicitações de teste e resultados
-- ---------------------------------------------------------------------------
create table if not exists public.table_requests (
  id uuid primary key default gen_random_uuid(),
  table_id uuid not null references public.tables(id) on delete cascade,
  target_member_id uuid not null references public.table_members(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  client_key uuid not null,                    -- idempotência do envio (retry não duplica)
  kind text not null check (kind in ('geral','combate')),
  params jsonb not null default '{}'::jsonb,   -- atributo, perícia, arma, dificuldade, rótulo...
  visibility text not null default 'publico',
  status text not null default 'pendente' check (status in ('pendente','respondido','cancelado')),
  result jsonb,
  created_at timestamptz not null default now(),
  answered_at timestamptz,
  master_ack_at timestamptz,                   -- mestre já processou o resultado (log/relógio) uma vez
  unique (table_id, client_key)
);
create index if not exists table_requests_table_idx on public.table_requests(table_id, created_at desc);
create index if not exists table_requests_target_pending_idx on public.table_requests(target_member_id) where status = 'pendente';

alter table public.table_requests enable row level security;
revoke all on public.table_requests from anon;
drop policy if exists "requests_owner_select" on public.table_requests;
create policy "requests_owner_select" on public.table_requests for select to authenticated
  using (exists(select 1 from public.tables t where t.id = table_requests.table_id and t.owner_id = auth.uid()));
drop policy if exists "requests_owner_update" on public.table_requests;
create policy "requests_owner_update" on public.table_requests for update to authenticated
  using (exists(select 1 from public.tables t where t.id = table_requests.table_id and t.owner_id = auth.uid()));
-- insert/delete diretos não são permitidos: o mestre cria via master_create_request.

-- ---------------------------------------------------------------------------
-- 4) Funções auxiliares (não expostas)
-- ---------------------------------------------------------------------------
create or replace function public._ad_hash(p_token text)
returns text language sql immutable set search_path = public as $$
  select encode(sha256(convert_to(coalesce(p_token,''), 'UTF8')), 'hex');
$$;

create or replace function public._ad_member_ok(p_member_id uuid, p_token text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(
    select 1 from public.table_members m
    left join public.table_member_secrets s on s.member_id = m.id
    where m.id = p_member_id and (
      (auth.uid() is not null and m.user_id = auth.uid())
      or (p_token is not null and length(p_token) >= 32 and s.token_hash = public._ad_hash(p_token))
    )
  );
$$;

create or replace function public._ad_is_owner(p_table_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and exists(select 1 from public.tables where id = p_table_id and owner_id = auth.uid());
$$;

revoke all on function public._ad_hash(text) from public, anon, authenticated;
revoke all on function public._ad_member_ok(uuid, text) from public, anon, authenticated;
revoke all on function public._ad_is_owner(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) Proteção dos campos reservados em table_members
--    As policies antigas de insert/update de table_members ainda são permissivas
--    (revisão no Ponto 2). Este trigger impede que um não-dono altere, por acesso
--    direto, consequências, prontidão, aprovação, status, vínculo ou identidade.
--    As funções abaixo marcam a transação como confiável (afterdark.trusted).
-- ---------------------------------------------------------------------------
create or replace function public._ad_members_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('afterdark.trusted', true), '') = 'on' then return new; end if;
  if public._ad_is_owner(coalesce(new.table_id, old.table_id)) then
    if tg_op = 'UPDATE' and new.table_id is distinct from old.table_id then
      raise exception 'table_id não pode ser alterado' using errcode = '42501';
    end if;
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.user_id is not null and new.user_id is distinct from auth.uid() then
      raise exception 'user_id inválido' using errcode = '42501';
    end if;
    new.wounds := '[]'::jsonb; new.conditions := '[]'::jsonb;
    new.sheet_ready := false; new.approved_at := null; new.approved_by := null;
    new.status := 'conectando';
    return new;
  end if;
  if new.wounds is distinct from old.wounds
     or new.conditions is distinct from old.conditions
     or new.sheet_ready is distinct from old.sheet_ready
     or new.approved_at is distinct from old.approved_at
     or new.approved_by is distinct from old.approved_by
     or new.status is distinct from old.status
     or new.table_id is distinct from old.table_id
     or new.user_id is distinct from old.user_id then
    raise exception 'campo reservado ao mestre ou às funções da mesa' using errcode = '42501';
  end if;
  return new;
end $$;

drop trigger if exists members_guard on public.table_members;
create trigger members_guard before insert or update on public.table_members
  for each row execute function public._ad_members_guard();

-- ---------------------------------------------------------------------------
-- 6) Ingresso: cria o membro e devolve o token (mostrado UMA vez ao cliente)
-- ---------------------------------------------------------------------------
create or replace function public.join_table_by_code(p_code text, p_player_name text default '')
returns table(member_id uuid, member_token text, table_id uuid, table_name text, table_type text, table_theme text)
language plpgsql security definer set search_path = public as $$
declare t record; v_token text; v_mid uuid;
begin
  select tb.id, tb.name, tb.type, tb.theme into t
    from public.tables tb where tb.invite_code = upper(trim(coalesce(p_code,'')));
  if not found then raise exception 'invalid_code' using errcode = 'P0002'; end if;
  perform set_config('afterdark.trusted', 'on', true);
  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into public.table_members(table_id, user_id, player_name, status)
    values (t.id, auth.uid(), left(coalesce(p_player_name,''), 80), 'conectando')
    returning id into v_mid;
  insert into public.table_member_secrets(member_id, token_hash) values (v_mid, public._ad_hash(v_token));
  return query select v_mid, v_token, t.id, t.name, t.type, t.theme;
end $$;

-- ---------------------------------------------------------------------------
-- 7) Funções do jogador (validam token ou auth.uid())
-- ---------------------------------------------------------------------------
-- Estado do próprio membro + solicitações destinadas a ele (pendentes e as últimas respondidas)
create or replace function public.player_get_state(p_member_id uuid, p_token text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare m record; reqs jsonb;
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select id, table_id, player_name, char_name, char_data, status, wounds, conditions, sheet_ready, approved_at
    into m from public.table_members where id = p_member_id;
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
    'requests', reqs);
end $$;

-- Responde uma solicitação. Só a primeira resposta vale; repetir devolve duplicate=true.
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
  update public.table_requests set status = 'respondido', result = p_result, answered_at = now()
    where id = p_request_id and target_member_id = p_member_id and status = 'pendente'
    returning id, status into r;
  if found then return jsonb_build_object('ok', true, 'duplicate', false); end if;
  select id, status into r from public.table_requests where id = p_request_id and target_member_id = p_member_id;
  if not found then raise exception 'request_not_found' using errcode = 'P0002'; end if;
  if r.status = 'respondido' then return jsonb_build_object('ok', true, 'duplicate', true); end if;
  raise exception 'request_cancelled' using errcode = 'P0001';
end $$;

-- Ficha concluída: grava ficha e marca "ficha concluída · aguardando aprovação".
-- Trocar a ficha zera uma aprovação anterior.
create or replace function public.player_submit_sheet(p_member_id uuid, p_token text, p_player_name text, p_char_name text, p_char_data jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  if coalesce(trim(p_char_name),'') = '' or p_char_data is null or jsonb_typeof(p_char_data) <> 'object'
     or pg_column_size(p_char_data) > 64000 then
    raise exception 'invalid_sheet' using errcode = '22023';
  end if;
  perform set_config('afterdark.trusted', 'on', true);
  update public.table_members set
      player_name = left(coalesce(p_player_name,''), 80), char_name = left(p_char_name, 80), char_data = p_char_data,
      sheet_ready = true, approved_at = null, approved_by = null, status = 'aguardando'
    where id = p_member_id;
  return jsonb_build_object('ok', true, 'status', 'aguardando');
end $$;

-- Prontidão do próprio jogador (desmarcar volta a "escolhendo" e zera a aprovação)
create or replace function public.player_set_ready(p_member_id uuid, p_token text, p_ready boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_char text;
begin
  if not public._ad_member_ok(p_member_id, p_token) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;
  select char_name into v_char from public.table_members where id = p_member_id;
  if p_ready and coalesce(v_char,'') = '' then raise exception 'sheet_missing' using errcode = 'P0001'; end if;
  perform set_config('afterdark.trusted', 'on', true);
  update public.table_members set
      sheet_ready = p_ready,
      approved_at = case when p_ready then approved_at else null end,
      approved_by = case when p_ready then approved_by else null end,
      status = case when not p_ready then 'escolhendo' when approved_at is not null then 'pronto' else 'aguardando' end
    where id = p_member_id;
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------------
-- 8) Funções do mestre (dono da mesa)
-- ---------------------------------------------------------------------------
create or replace function public.master_create_request(p_table_id uuid, p_member_id uuid, p_client_key uuid,
  p_kind text, p_params jsonb, p_visibility text default 'publico')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_char text;
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  select char_name into v_char from public.table_members where id = p_member_id and table_id = p_table_id;
  if not found then raise exception 'target_not_in_table' using errcode = 'P0002'; end if;
  if coalesce(v_char,'') = '' then raise exception 'target_without_sheet' using errcode = 'P0001'; end if;
  if p_kind not in ('geral','combate') or p_params is null or pg_column_size(p_params) > 16000 then
    raise exception 'invalid_request' using errcode = '22023';
  end if;
  insert into public.table_requests(table_id, target_member_id, created_by, client_key, kind, params, visibility)
    values (p_table_id, p_member_id, auth.uid(), p_client_key, p_kind, p_params, coalesce(p_visibility,'publico'))
    on conflict (table_id, client_key) do nothing
    returning id into v_id;
  if v_id is null then
    select id into v_id from public.table_requests where table_id = p_table_id and client_key = p_client_key;
    return jsonb_build_object('ok', true, 'id', v_id, 'duplicate', true);
  end if;
  return jsonb_build_object('ok', true, 'id', v_id, 'duplicate', false);
end $$;

-- Marca um resultado como processado pelo mestre. Devolve true só na PRIMEIRA vez
-- (evita registrar o mesmo resultado duas vezes no log/relógio após F5 ou 2 abas).
create or replace function public.master_ack_request(p_request_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_table uuid;
begin
  select table_id into v_table from public.table_requests where id = p_request_id;
  if v_table is null or not public._ad_is_owner(v_table) then raise exception 'not_authorized' using errcode = '42501'; end if;
  update public.table_requests set master_ack_at = now()
    where id = p_request_id and status = 'respondido' and master_ack_at is null;
  return found;
end $$;

create or replace function public.master_cancel_request(p_request_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_table uuid;
begin
  select table_id into v_table from public.table_requests where id = p_request_id;
  if v_table is null or not public._ad_is_owner(v_table) then raise exception 'not_authorized' using errcode = '42501'; end if;
  update public.table_requests set status = 'cancelado' where id = p_request_id and status = 'pendente';
  return found;
end $$;

-- Ferimentos e condições: operações atômicas (sem sobrescrever escrita concorrente).
-- p_action: add_wound {lvl,desc} | remove_wound {id} | add_condition {name} | remove_condition {name}
create or replace function public.master_member_consequence(p_member_id uuid, p_action text, p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_table uuid; v_w jsonb; v_c jsonb; v_name text;
begin
  select table_id into v_table from public.table_members where id = p_member_id;
  if v_table is null or not public._ad_is_owner(v_table) then raise exception 'not_authorized' using errcode = '42501'; end if;
  perform set_config('afterdark.trusted', 'on', true);
  if p_action = 'add_wound' then
    if coalesce(p_payload->>'lvl','') = '' then raise exception 'invalid_payload' using errcode = '22023'; end if;
    -- 'op' = chave da operação no cliente: repetir a mesma tentativa não duplica o ferimento
    update public.table_members set wounds = wounds || jsonb_build_array(jsonb_build_object(
        'id', gen_random_uuid(), 'op', left(coalesce(p_payload->>'op',''), 64), 'lvl', left(p_payload->>'lvl', 20),
        'desc', left(coalesce(p_payload->>'desc',''), 200), 'at', now()))
      where id = p_member_id
        and (coalesce(p_payload->>'op','') = '' or not exists(
          select 1 from jsonb_array_elements(wounds) w where w->>'op' = p_payload->>'op'));
  elsif p_action = 'remove_wound' then
    update public.table_members set wounds = coalesce((
        select jsonb_agg(w order by ord) from jsonb_array_elements(wounds) with ordinality as e(w, ord)
        where w->>'id' is distinct from p_payload->>'id'), '[]'::jsonb)
      where id = p_member_id;
  elsif p_action = 'add_condition' then
    v_name := left(trim(coalesce(p_payload->>'name','')), 80);
    if v_name = '' then raise exception 'invalid_payload' using errcode = '22023'; end if;
    update public.table_members set conditions = conditions || to_jsonb(v_name)
      where id = p_member_id and not (conditions ? v_name);
  elsif p_action = 'remove_condition' then
    update public.table_members set conditions = coalesce((
        select jsonb_agg(c order by ord) from jsonb_array_elements(conditions) with ordinality as e(c, ord)
        where c #>> '{}' is distinct from p_payload->>'name'), '[]'::jsonb)
      where id = p_member_id;
  else
    raise exception 'invalid_action' using errcode = '22023';
  end if;
  select wounds, conditions into v_w, v_c from public.table_members where id = p_member_id;
  return jsonb_build_object('ok', true, 'wounds', v_w, 'conditions', v_c);
end $$;

create or replace function public.master_set_approval(p_member_id uuid, p_approved boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_table uuid; v_ready boolean;
begin
  select table_id, sheet_ready into v_table, v_ready from public.table_members where id = p_member_id;
  if v_table is null or not public._ad_is_owner(v_table) then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_approved and not v_ready then raise exception 'sheet_not_ready' using errcode = 'P0001'; end if;
  perform set_config('afterdark.trusted', 'on', true);
  update public.table_members set
      approved_at = case when p_approved then now() else null end,
      approved_by = case when p_approved then auth.uid() else null end,
      status = case when p_approved then 'pronto' when sheet_ready then 'aguardando' else status end
    where id = p_member_id;
  return jsonb_build_object('ok', true);
end $$;

-- Início de sessão com guarda: exige ao menos um jogador e TODOS aprovados.
create or replace function public.master_start_session(p_table_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_total int; v_pending int;
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  select count(*), count(*) filter (where approved_at is null) into v_total, v_pending
    from public.table_members where table_id = p_table_id;
  if v_total = 0 then raise exception 'no_players' using errcode = 'P0001'; end if;
  if v_pending > 0 then raise exception 'players_not_approved' using errcode = 'P0001'; end if;
  update public.tables set status = 'Em andamento' where id = p_table_id;
  return jsonb_build_object('ok', true);
end $$;

-- ---------------------------------------------------------------------------
-- 9) Grants: só as funções públicas da mesa; auxiliares ficam fechadas
-- ---------------------------------------------------------------------------
revoke all on function public.join_table_by_code(text, text) from public;
revoke all on function public.player_get_state(uuid, text) from public;
revoke all on function public.player_answer_request(uuid, text, uuid, jsonb) from public;
revoke all on function public.player_submit_sheet(uuid, text, text, text, jsonb) from public;
revoke all on function public.player_set_ready(uuid, text, boolean) from public;
revoke all on function public.master_create_request(uuid, uuid, uuid, text, jsonb, text) from public, anon;
revoke all on function public.master_ack_request(uuid) from public, anon;
revoke all on function public.master_cancel_request(uuid) from public, anon;
revoke all on function public.master_member_consequence(uuid, text, jsonb) from public, anon;
revoke all on function public.master_set_approval(uuid, boolean) from public, anon;
revoke all on function public.master_start_session(uuid) from public, anon;
revoke all on function public._ad_members_guard() from public, anon, authenticated;

grant execute on function public.join_table_by_code(text, text) to anon, authenticated;
grant execute on function public.player_get_state(uuid, text) to anon, authenticated;
grant execute on function public.player_answer_request(uuid, text, uuid, jsonb) to anon, authenticated;
grant execute on function public.player_submit_sheet(uuid, text, text, text, jsonb) to anon, authenticated;
grant execute on function public.player_set_ready(uuid, text, boolean) to anon, authenticated;
grant execute on function public.master_create_request(uuid, uuid, uuid, text, jsonb, text) to authenticated;
grant execute on function public.master_ack_request(uuid) to authenticated;
grant execute on function public.master_cancel_request(uuid) to authenticated;
grant execute on function public.master_member_consequence(uuid, text, jsonb) to authenticated;
grant execute on function public.master_set_approval(uuid, boolean) to authenticated;
grant execute on function public.master_start_session(uuid) to authenticated;

-- Membros que já estavam "pronto" antes desta migração: marca ficha concluída e
-- aprovada, para não travar mesas em andamento.
do $$
begin
  perform set_config('afterdark.trusted', 'on', true);
  update public.table_members set sheet_ready = true, approved_at = coalesce(approved_at, updated_at)
    where status = 'pronto' and sheet_ready = false and char_name is not null;
end $$;

notify pgrst, 'reload schema';
