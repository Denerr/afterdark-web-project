-- Afterdark — migração (Ponto 3): salvamento confirmado, versão por mesa, notas
-- privadas do Mestre e biblioteca do Mestre por conta.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Item 12 da ordem do INSTALL.md (depois de migration_player_projection.sql).
--
-- Ordem com o deploy: LIVRE. Só adiciona colunas, um trigger e funções novas; não
-- altera policy nem grant existentes. O cliente antigo continua gravando
-- session_state direto (o trigger abaixo incrementa a versão mesmo assim, então o
-- cliente novo detecta essa escrita como conflito em vez de sobrescrevê-la).
--
-- Decisões (aprovadas para o Ponto 3):
--  * Conflito entre duas abas do Mestre: controle otimista por versão. Quem tenta
--    gravar sobre uma versão mais nova é recusado e recarrega o estado mais recente.
--  * Roteiro, narrativa e marcações ficam em tables.master_notes — privado do dono
--    (RLS de tables já restringe a leitura ao owner; nenhuma função de jogador lê
--    esta coluna).
--  * Armas, itens, ferimentos e condições pré-cadastrados acompanham a CONTA do
--    Mestre: profiles.master_library (RLS de profiles: só o próprio usuário).

-- ---------------------------------------------------------------------------
-- 1) Colunas
-- ---------------------------------------------------------------------------
alter table public.tables
  add column if not exists session_version bigint not null default 0,
  add column if not exists master_notes jsonb not null default '{}'::jsonb;

alter table public.profiles
  add column if not exists master_library jsonb not null default '{}'::jsonb;

-- ---------------------------------------------------------------------------
-- 2) Toda escrita de session_state/master_notes avança a versão
--    (inclusive um update direto de um cliente antigo, que não conhece a versão).
-- ---------------------------------------------------------------------------
create or replace function public._ad_tables_version()
returns trigger language plpgsql set search_path = public as $$
begin
  if (new.session_state is distinct from old.session_state
      or new.master_notes is distinct from old.master_notes)
     and new.session_version is not distinct from old.session_version then
    new.session_version := old.session_version + 1;
  end if;
  return new;
end $$;

drop trigger if exists tables_session_version on public.tables;
create trigger tables_session_version before update on public.tables
  for each row execute function public._ad_tables_version();
revoke all on function public._ad_tables_version() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) Leitura do Mestre: estado + notas + versão numa só chamada
-- ---------------------------------------------------------------------------
create or replace function public.master_get_session(p_table_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r record;
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  select session_state, master_notes, session_version, status into r from public.tables where id = p_table_id;
  return jsonb_build_object('state', coalesce(r.session_state, '{}'::jsonb), 'notes', coalesce(r.master_notes, '{}'::jsonb),
    'version', r.session_version, 'status', r.status);
end $$;

-- ---------------------------------------------------------------------------
-- 4) Gravação do Mestre com versão: grava só se ninguém gravou depois da leitura
--    p_notes null = não altera as notas.
-- ---------------------------------------------------------------------------
create or replace function public.master_save_session(p_table_id uuid, p_state jsonb, p_notes jsonb, p_base_version bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_new bigint; v_cur bigint;
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_state is null or jsonb_typeof(p_state) <> 'object' or pg_column_size(p_state) > 2000000 then
    raise exception 'invalid_state' using errcode = '22023';
  end if;
  if p_notes is not null and (jsonb_typeof(p_notes) <> 'object' or pg_column_size(p_notes) > 500000) then
    raise exception 'invalid_notes' using errcode = '22023';
  end if;
  update public.tables
     set session_state = p_state,
         master_notes = coalesce(p_notes, master_notes),
         session_version = session_version + 1
   where id = p_table_id and session_version = p_base_version
   returning session_version into v_new;
  if found then return jsonb_build_object('ok', true, 'version', v_new); end if;
  select session_version into v_cur from public.tables where id = p_table_id;
  if v_cur is null then raise exception 'table_not_found' using errcode = 'P0002'; end if;
  return jsonb_build_object('ok', false, 'conflict', true, 'version', v_cur);
end $$;

-- ---------------------------------------------------------------------------
-- 5) Pausar / encerrar com confirmação. Retomar continua sendo master_start_session
--    (mantém a guarda de aprovação do Ponto 1).
-- ---------------------------------------------------------------------------
create or replace function public.master_set_status(p_table_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  if p_status not in ('Pausada · retomar depois', 'Encerrada') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;
  update public.tables set status = p_status where id = p_table_id;
  return jsonb_build_object('ok', true, 'status', p_status);
end $$;

-- ---------------------------------------------------------------------------
-- 6) Grants
-- ---------------------------------------------------------------------------
revoke all on function public.master_get_session(uuid) from public, anon;
revoke all on function public.master_save_session(uuid, jsonb, jsonb, bigint) from public, anon;
revoke all on function public.master_set_status(uuid, text) from public, anon;
grant execute on function public.master_get_session(uuid) to authenticated;
grant execute on function public.master_save_session(uuid, jsonb, jsonb, bigint) to authenticated;
grant execute on function public.master_set_status(uuid, text) to authenticated;

notify pgrst, 'reload schema';
