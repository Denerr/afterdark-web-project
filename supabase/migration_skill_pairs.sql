-- Afterdark — migração (UI Etapa 5): par atributo/perícia validado no banco.
-- Rodar no painel do Supabase: SQL Editor > New query > colar e executar.
-- Idempotente. Depende de migration_requests_consequences.sql (Ponto 1).
--
-- Cada atributo só aceita as próprias perícias, sem combinação cruzada. O app já
-- filtra a lista; o banco valida de novo, porque o cliente não é fonte de verdade.
--
-- A tabela abaixo ESPELHA src/data/attributes.js. Os dois precisam mudar juntos:
-- tests/parity_skills.js compara os dois e falha se divergirem.
--
-- Compatibilidade:
--   * A validação vale só para pedidos NOVOS. Pedido já gravado (inclusive com par
--     antigo, como 'mente' + 'analise') continua respondível e reenviável:
--     player_answer_request não olha o par.
--   * Nova tentativa com a mesma client_key de um pedido que já existe devolve a
--     duplicata ANTES de validar o par — um reenvio legítimo não vira erro.

create or replace function public._ad_skill_attr(p_skill text)
returns text language sql immutable set search_path = public as $$
  select a from (values
    ('atletismo','corpo'),
    ('luta','corpo'),
    ('resistencia','corpo'),
    ('protecao','corpo'),
    ('pontaria','reflexo'),
    ('furtividade','reflexo'),
    ('conducao','reflexo'),
    ('crime','reflexo'),
    ('investigacao','mente'),
    ('conhecimento','mente'),
    ('tecnologia','mente'),
    ('medicina','mente'),
    ('persuasao','presenca'),
    ('enganacao','presenca'),
    ('intimidacao','presenca'),
    ('etiqueta','presenca'),
    ('percepcao','instinto'),
    ('intuicao','instinto'),
    ('rastreamento','instinto'),
    ('autocontrole','instinto'),
    ('sensibilidade','espirito'),
    ('ocultismo','espirito'),
    ('rituais','espirito'),
    ('resistencia_espiritual','espirito')
  ) as v(s, a) where s = p_skill;
$$;
revoke all on function public._ad_skill_attr(text) from public, anon, authenticated;

create or replace function public.master_create_request(p_table_id uuid, p_member_id uuid, p_client_key uuid,
  p_kind text, p_params jsonb, p_visibility text default 'publico')
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_char text; v_attr text; v_skill text;
begin
  if not public._ad_is_owner(p_table_id) then raise exception 'not_authorized' using errcode = '42501'; end if;
  select char_name into v_char from public.table_members where id = p_member_id and table_id = p_table_id;
  if not found then raise exception 'target_not_in_table' using errcode = 'P0002'; end if;
  if coalesce(v_char,'') = '' then raise exception 'target_without_sheet' using errcode = 'P0001'; end if;
  if p_kind not in ('geral','combate') or p_params is null or pg_column_size(p_params) > 16000 then
    raise exception 'invalid_request' using errcode = '22023';
  end if;
  -- reenvio de um pedido que ja existe: devolve o existente, sem revalidar o par
  select id into v_id from public.table_requests where table_id = p_table_id and client_key = p_client_key;
  if found then return jsonb_build_object('ok', true, 'id', v_id, 'duplicate', true); end if;
  v_attr := p_params->>'attrKey';
  v_skill := p_params->>'skillKey';
  if v_attr is null or v_skill is null or public._ad_skill_attr(v_skill) is distinct from v_attr then
    raise exception 'invalid_skill_for_attr' using errcode = '22023';
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

revoke all on function public.master_create_request(uuid, uuid, uuid, text, jsonb, text) from public, anon;
grant execute on function public.master_create_request(uuid, uuid, uuid, text, jsonb, text) to authenticated;
