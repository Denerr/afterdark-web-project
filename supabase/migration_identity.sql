-- Afterdark — migração (Pós-sessão, Etapa 0): identidade do participante e aba Mesas.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_rls_p2.sql (Ponto 2).
--
-- Problema: join_table_by_code criava um membro NOVO a cada chamada. Reabrir o link,
-- entrar de novo depois de uma pausa ou fazer login no meio da entrada gerava um
-- segundo participante (e uma segunda ficha) para a mesma pessoa.
--
-- Agora a entrada é repetível:
--   * Credencial de visitante já guardada no navegador (member_id + token) que pertence
--     à mesa do código -> reaproveita o mesmo membro. O banco confere o token.
--   * Conta autenticada que já participa da mesa -> reaproveita a participação da conta.
--   * Visitante que fez login durante a entrada (credencial válida + conta sem
--     participação na mesa) -> o membro do visitante passa a ser da conta. Ficha,
--     aprovação, consequências e solicitações ficam onde estão: é o mesmo registro.
--   * Conta que JÁ tem outra participação na mesa -> nada é fundido nem substituído;
--     a função devolve as duas e o app pergunta qual usar.
--   * O dono da mesa não entra como jogador na própria mesa (decisão de 08/10/2026).
-- Nome, foto ou e-mail informados pelo navegador nunca servem de prova de identidade.
--
-- Ordem: aplicar ESTA migração antes de publicar o index.html da Etapa 0. O cliente
-- novo envia p_creds, que o banco antigo não conhece. O cliente antigo continua
-- funcionando com o banco novo (os parâmetros novos têm valor padrão).

-- ---------------------------------------------------------------------------
-- 1) Arquivo de participações removidas pela correção de duplicatas (recuperação)
--    Sem policy e sem grant: só o painel do Supabase lê.
-- ---------------------------------------------------------------------------
create table if not exists public._ad_members_archive (
  id bigint generated always as identity primary key,
  member_id uuid not null,
  kept_member_id uuid,
  table_id uuid,
  row_data jsonb not null,
  token_hash text,
  reason text not null,
  archived_at timestamptz not null default now()
);
alter table public._ad_members_archive enable row level security;
revoke all on public._ad_members_archive from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) Entrada repetível
-- ---------------------------------------------------------------------------
drop function if exists public.join_table_by_code(text, text);
drop function if exists public.join_table_by_code(text, text, jsonb);
create or replace function public.join_table_by_code(p_code text, p_player_name text default '', p_creds jsonb default '[]'::jsonb)
returns table(member_id uuid, member_token text, table_id uuid, table_name text, table_type text, table_theme text,
              reused boolean, linked boolean, char_name text, conflict_member_id uuid, conflict_char_name text)
language plpgsql security definer set search_path = public as $$
declare
  t record; v_uid uuid := auth.uid(); v_token text; v_mid uuid;
  c jsonb; v_cmid uuid; v_ctok text; v_cred uuid; v_ctoken text; v_cuser uuid;
  v_acc uuid; v_acc_char text; v_cred_char text;
begin
  select tb.id, tb.name, tb.type, tb.theme, tb.owner_id into t
    from public.tables tb where tb.invite_code = upper(trim(coalesce(p_code,'')));
  if not found then raise exception 'invalid_code' using errcode = 'P0002'; end if;
  if v_uid is not null and t.owner_id = v_uid then
    raise exception 'owner_cannot_join' using errcode = '42501';
  end if;
  perform set_config('afterdark.trusted', 'on', true);

  -- Serializa entradas concorrentes da mesma conta (duas abas, clique repetido).
  if v_uid is not null then
    perform pg_advisory_xact_lock(hashtextextended(t.id::text || ':' || v_uid::text, 0));
  end if;

  -- a) credencial de visitante guardada no navegador: vale só com o token certo
  --    e só se o membro for desta mesa
  if jsonb_typeof(p_creds) = 'array' then
    for c in select value from jsonb_array_elements(p_creds) limit 50 loop
      begin
        v_cmid := (c->>'member_id')::uuid; v_ctok := c->>'token';
      exception when others then continue; end;
      if v_ctok is null or length(v_ctok) < 32 then continue; end if;
      select m.id, m.user_id, m.char_name into v_cred, v_cuser, v_cred_char
        from public.table_members m
        join public.table_member_secrets s on s.member_id = m.id
       where m.id = v_cmid and m.table_id = t.id and s.token_hash = public._ad_hash(v_ctok);
      if found then
        -- credencial de OUTRA conta logada (computador compartilhado): ignorada, não
        -- prova que esta pessoa é aquele participante. Sem login, o token sozinho vale,
        -- como em todas as outras funções do jogador (_ad_member_ok).
        if v_cuser is not null and v_uid is not null and v_cuser <> v_uid then
          v_cred := null; continue;
        end if;
        v_ctoken := v_ctok; exit;
      end if;
      v_cred := null;
    end loop;
  end if;

  -- b) participação da conta nesta mesa
  if v_uid is not null then
    select m.id, m.char_name into v_acc, v_acc_char from public.table_members m
     where m.table_id = t.id and m.user_id = v_uid order by m.joined_at limit 1;
  end if;

  if v_cred is not null and v_uid is not null and v_cuser is null then
    if v_acc is not null and v_acc <> v_cred then
      -- conflito: a conta já tem uma ficha aqui. Nada é fundido; o app pergunta.
      return query select v_acc, null::text, t.id, t.name, t.type, t.theme, true, false, v_acc_char, v_cred, v_cred_char;
      return;
    end if;
    update public.table_members set user_id = v_uid, updated_at = now() where id = v_cred;
    return query select v_cred, v_ctoken, t.id, t.name, t.type, t.theme, true, true, v_cred_char, null::uuid, null::text;
    return;
  end if;
  if v_cred is not null then
    return query select v_cred, v_ctoken, t.id, t.name, t.type, t.theme, true, false, v_cred_char, null::uuid, null::text;
    return;
  end if;
  if v_acc is not null then
    -- a conta entra sem token (auth.uid() já autoriza)
    return query select v_acc, null::text, t.id, t.name, t.type, t.theme, true, false, v_acc_char, null::uuid, null::text;
    return;
  end if;

  -- c) entrada nova
  v_token := replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', '');
  insert into public.table_members(table_id, user_id, player_name, status)
    values (t.id, v_uid, left(coalesce(p_player_name,''), 80), 'conectando')
    returning id into v_mid;
  insert into public.table_member_secrets(member_id, token_hash) values (v_mid, public._ad_hash(v_token));
  return query select v_mid, v_token, t.id, t.name, t.type, t.theme, false, false, null::text, null::uuid, null::text;
end $$;
revoke all on function public.join_table_by_code(text, text, jsonb) from public;
grant execute on function public.join_table_by_code(text, text, jsonb) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) Vincular à conta uma participação de visitante (ação explícita no Perfil)
--    Exige as duas provas: o token do visitante E a sessão autenticada.
-- ---------------------------------------------------------------------------
create or replace function public.player_link_account(p_member_id uuid, p_token text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); m record; v_owner uuid; v_other uuid;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_token is null or length(p_token) < 32 then raise exception 'not_authorized' using errcode = '42501'; end if;
  select tm.id, tm.table_id, tm.user_id into m
    from public.table_members tm join public.table_member_secrets s on s.member_id = tm.id
   where tm.id = p_member_id and s.token_hash = public._ad_hash(p_token);
  if not found then raise exception 'not_authorized' using errcode = '42501'; end if;
  if m.user_id = v_uid then return jsonb_build_object('ok', true, 'already', true); end if;
  if m.user_id is not null then raise exception 'member_other_account' using errcode = '42501'; end if;
  select owner_id into v_owner from public.tables where id = m.table_id;
  if v_owner = v_uid then raise exception 'owner_cannot_join' using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(m.table_id::text || ':' || v_uid::text, 0));
  select id into v_other from public.table_members where table_id = m.table_id and user_id = v_uid limit 1;
  if v_other is not null then
    return jsonb_build_object('ok', false, 'conflict', true, 'member_id', v_other);
  end if;
  perform set_config('afterdark.trusted', 'on', true);
  update public.table_members set user_id = v_uid, updated_at = now() where id = p_member_id;
  return jsonb_build_object('ok', true, 'linked', true);
end $$;
revoke all on function public.player_link_account(uuid, text) from public, anon;
grant execute on function public.player_link_account(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Aba Mesas: participações como jogador
-- ---------------------------------------------------------------------------
-- Pela conta (qualquer navegador/dispositivo)
create or replace function public.my_memberships()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'member_id', m.id, 'table_id', t.id, 'table_name', t.name, 'table_type', t.type,
      'table_theme', t.theme, 'table_status', t.status, 'archived', coalesce(t.archived, false),
      'char_name', m.char_name, 'player_name', m.player_name,
      'sheet_ready', m.sheet_ready, 'approved', m.approved_at is not null,
      'joined_at', m.joined_at
    ) order by m.joined_at desc), '[]'::jsonb)
  from public.table_members m join public.tables t on t.id = m.table_id
  where auth.uid() is not null and m.user_id = auth.uid() and t.owner_id is distinct from auth.uid();
$$;
revoke all on function public.my_memberships() from public, anon;
grant execute on function public.my_memberships() to authenticated;

-- Pelas credenciais de visitante guardadas neste navegador. Credencial inválida ou
-- participação removida volta como valid=false (o app mostra "indisponível").
create or replace function public.player_check_memberships(p_creds jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c jsonb; v_mid uuid; v_tok text; r record; out jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_creds) <> 'array' then return out; end if;
  for c in select value from jsonb_array_elements(p_creds) limit 50 loop
    begin v_mid := (c->>'member_id')::uuid; exception when others then continue; end;
    v_tok := c->>'token';
    select m.id, m.user_id, m.char_name, m.player_name, m.sheet_ready, m.approved_at,
           t.id as tid, t.name, t.type, t.theme, t.status, t.archived
      into r
      from public.table_members m
      join public.table_member_secrets s on s.member_id = m.id
      join public.tables t on t.id = m.table_id
     where m.id = v_mid and v_tok is not null and length(v_tok) >= 32 and s.token_hash = public._ad_hash(v_tok);
    if not found then
      out := out || jsonb_build_array(jsonb_build_object('member_id', v_mid, 'valid', false));
    else
      out := out || jsonb_build_array(jsonb_build_object(
        'member_id', r.id, 'valid', true, 'table_id', r.tid, 'table_name', r.name, 'table_type', r.type,
        'table_theme', r.theme, 'table_status', r.status, 'archived', coalesce(r.archived, false),
        'char_name', r.char_name, 'player_name', r.player_name, 'sheet_ready', r.sheet_ready,
        'approved', r.approved_at is not null,
        'linked', r.user_id is not null, 'mine', r.user_id is not null and r.user_id = auth.uid()));
    end if;
  end loop;
  return out;
end $$;
revoke all on function public.player_check_memberships(jsonb) from public;
grant execute on function public.player_check_memberships(jsonb) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) Correção de duplicatas existentes (uso manual, pelo painel)
--    Une duas participações da MESMA conta na mesma mesa: as solicitações e as
--    referências do estado da sessão passam para p_keep; p_drop é arquivado em
--    _ad_members_archive (com o hash do token) e removido. Recusa participações de
--    contas diferentes, de visitantes ou de mesas diferentes: nada é inferido pelo nome.
--    Uso:  select public._ad_merge_member('<id que fica>', '<id que sai>');
-- ---------------------------------------------------------------------------
create or replace function public._ad_merge_member(p_keep uuid, p_drop uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare k record; d record; v_hash text; v_reqs int;
begin
  if p_keep = p_drop then raise exception 'mesmo membro'; end if;
  select * into k from public.table_members where id = p_keep;
  if not found then raise exception 'membro que fica não existe'; end if;
  select * into d from public.table_members where id = p_drop;
  if not found then raise exception 'membro que sai não existe'; end if;
  if k.table_id <> d.table_id then raise exception 'mesas diferentes'; end if;
  if k.user_id is null or d.user_id is null or k.user_id <> d.user_id then
    raise exception 'só une participações da mesma conta';
  end if;
  perform set_config('afterdark.trusted', 'on', true);
  select token_hash into v_hash from public.table_member_secrets where member_id = p_drop;
  insert into public._ad_members_archive(member_id, kept_member_id, table_id, row_data, token_hash, reason)
    values (p_drop, p_keep, d.table_id, to_jsonb(d), v_hash, 'duplicata da mesma conta');
  update public.table_requests set target_member_id = p_keep where target_member_id = p_drop;
  get diagnostics v_reqs = row_count;
  -- estado da sessão: barras de estresse, visibilidade do log etc. citam o id do membro
  update public.tables set session_state = replace(session_state::text, p_drop::text, p_keep::text)::jsonb
   where id = d.table_id and session_state::text like '%' || p_drop::text || '%';
  delete from public.table_members where id = p_drop;
  return jsonb_build_object('ok', true, 'requests_moved', v_reqs);
end $$;
revoke all on function public._ad_merge_member(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6) Uma participação por conta e mesa (garantia no banco)
--    Só é criada quando não há duplicata. Havendo, a migração AVISA e segue: a entrada
--    nova já não cria duplicatas (trava por conta acima). Depois de resolver as
--    duplicatas com _ad_merge_member, rode esta migração de novo para criar o índice.
-- ---------------------------------------------------------------------------
do $$
declare n int;
begin
  select count(*) into n from (
    select 1 from public.table_members where user_id is not null
     group by table_id, user_id having count(*) > 1) x;
  if n = 0 then
    create unique index if not exists table_members_one_per_account
      on public.table_members(table_id, user_id) where user_id is not null;
  else
    raise warning 'Afterdark: % conta(s) com participação duplicada na mesma mesa. Índice de unicidade NÃO criado. Resolva com _ad_merge_member e rode esta migração de novo.', n;
  end if;
end $$;
