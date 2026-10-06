-- Testes SQL da UI Etapa 5: par atributo/pericia validado no banco.
-- Rodar numa base limpa, com as migracoes na ordem do INSTALL.md (ou via run_all.sh).
-- Esperado: 16 linhas PASSOU e 'TODOS OS TESTES DA ETAPA 5 PASSARAM'.
\set ON_ERROR_STOP 1

create schema t;
grant usage on schema t to anon, authenticated;
create function t.ok(c boolean, msg text) returns void language plpgsql as $fn$
begin if c is not true then raise exception 'FALHOU: %', msg; end if; raise notice 'PASSOU: %', msg; end $fn$;
create function t.fails(q text, msg text, pat text default null) returns void language plpgsql as $fn$
begin
  begin execute q; exception when others then
    if pat is not null and sqlerrm !~ pat then raise exception 'FALHOU (erro inesperado "%"): %', sqlerrm, msg; end if;
    raise notice 'PASSOU (bloqueado: %): %', sqlerrm, msg; return;
  end;
  raise exception 'FALHOU (deveria bloquear): %', msg;
end $fn$;
grant execute on all functions in schema t to anon, authenticated;
create function t.v(k text) returns text language sql stable as $fn$ select current_setting('t.'||k) $fn$;
grant execute on function t.v(text) to anon, authenticated;

insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111');

set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa E5','SV-E501') returning id as ta \gset
select set_config('t.ta', :'ta', false);

reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as toka from public.join_table_by_code('SV-E501','Ana') \gset
select set_config('t.ma',:'ma',false), set_config('t.toka',:'toka',false);
select public.player_submit_sheet(:'ma',:'toka','Ana','Kara','{"sens":"vampiros"}');

-- ------------------------------------------------------------ pedidos novos
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.ok((public.master_create_request(t.v('ta')::uuid, t.v('ma')::uuid, gen_random_uuid(), 'geral',
  '{"attrKey":"mente","skillKey":"investigacao"}'::jsonb)->>'ok')::boolean, 'par valido no teste geral (Mente + Investigacao)');
select t.ok((public.master_create_request(t.v('ta')::uuid, t.v('ma')::uuid, gen_random_uuid(), 'combate',
  '{"attrKey":"corpo","skillKey":"luta","atkTargetKind":"npc"}'::jsonb)->>'ok')::boolean, 'par valido no combate (Corpo + Luta)');
select t.fails(format($q$select public.master_create_request(%L,%L,gen_random_uuid(),'geral','{"attrKey":"mente","skillKey":"atletismo"}')$q$, t.v('ta'), t.v('ma')),
  'combinacao cruzada recusada (Mente + Atletismo)', 'invalid_skill_for_attr');
select t.fails(format($q$select public.master_create_request(%L,%L,gen_random_uuid(),'combate','{"attrKey":"reflexo","skillKey":"luta"}')$q$, t.v('ta'), t.v('ma')),
  'combinacao cruzada recusada no combate (Reflexos + Luta)', 'invalid_skill_for_attr');
select t.fails(format($q$select public.master_create_request(%L,%L,gen_random_uuid(),'geral','{"attrKey":"mente","skillKey":"analise"}')$q$, t.v('ta'), t.v('ma')),
  'pericia inexistente recusada (padrao antigo "analise")', 'invalid_skill_for_attr');
select t.fails(format($q$select public.master_create_request(%L,%L,gen_random_uuid(),'geral','{"attrKey":"mente"}')$q$, t.v('ta'), t.v('ma')),
  'pedido sem pericia recusado', 'invalid_skill_for_attr');
select t.fails(format($q$select public.master_create_request(%L,%L,gen_random_uuid(),'geral','{"skillKey":"investigacao"}')$q$, t.v('ta'), t.v('ma')),
  'pedido sem atributo recusado', 'invalid_skill_for_attr');
select t.fails(format($q$select public.master_create_request(%L,%L,gen_random_uuid(),'geral','{"attrKey":"Mente","skillKey":"investigacao"}')$q$, t.v('ta'), t.v('ma')),
  'chave de atributo com grafia diferente recusada', 'invalid_skill_for_attr');

-- as 24 pericias do catalogo, cada uma com o proprio atributo, sao aceitas
do $$
declare r record; n int := 0;
begin
  for r in select * from (values
    ('atletismo','corpo'),('luta','corpo'),('resistencia','corpo'),('protecao','corpo'),
    ('pontaria','reflexo'),('furtividade','reflexo'),('conducao','reflexo'),('crime','reflexo'),
    ('investigacao','mente'),('conhecimento','mente'),('tecnologia','mente'),('medicina','mente'),
    ('persuasao','presenca'),('enganacao','presenca'),('intimidacao','presenca'),('etiqueta','presenca'),
    ('percepcao','instinto'),('intuicao','instinto'),('rastreamento','instinto'),('autocontrole','instinto'),
    ('sensibilidade','espirito'),('ocultismo','espirito'),('rituais','espirito'),('resistencia_espiritual','espirito')
  ) v(s,a) loop
    perform public.master_create_request(current_setting('t.ta')::uuid, current_setting('t.ma')::uuid, gen_random_uuid(),
      'geral', jsonb_build_object('attrKey', r.a, 'skillKey', r.s));
    n := n + 1;
  end loop;
  perform t.ok(n = 24, 'as 24 pericias do catalogo aceitas com o proprio atributo');
end $$;
select t.ok((select count(*) from public.table_requests where table_id = t.v('ta')::uuid) = 26,
  'nenhum pedido invalido foi gravado (26 = 2 validos + 24 do catalogo)');

-- --------------------------------------------- compatibilidade com o legado
-- pedido gravado ANTES da migracao, com o par antigo 'mente' + 'analise'
reset role;
insert into public.table_requests(table_id, target_member_id, created_by, client_key, kind, params)
  values (t.v('ta')::uuid, t.v('ma')::uuid, '11111111-1111-1111-1111-111111111111',
          'eeeeeeee-0000-0000-0000-000000000001', 'geral', '{"attrKey":"mente","skillKey":"analise"}')
  returning id as rleg \gset
select set_config('t.rleg', :'rleg', false);

set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.ok((public.master_create_request(t.v('ta')::uuid, t.v('ma')::uuid, 'eeeeeeee-0000-0000-0000-000000000001', 'geral',
  '{"attrKey":"mente","skillKey":"analise"}'::jsonb)->>'duplicate')::boolean,
  'reenvio de pedido antigo (mesma client_key) devolve a duplicata em vez de erro');

reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.ok(public.player_get_state(t.v('ma')::uuid, t.v('toka'))::text like '%analise%',
  'pedido antigo pendente continua chegando ao jogador');
select t.ok(not (public.player_answer_request(t.v('ma')::uuid, t.v('toka'), t.v('rleg')::uuid,
  '{"total":14,"grade":"Sucesso Completo"}'::jsonb)->>'duplicate')::boolean,
  'pedido antigo pendente continua respondivel');
select t.ok((public.player_answer_request(t.v('ma')::uuid, t.v('toka'), t.v('rleg')::uuid,
  '{"total":14,"grade":"Sucesso Completo"}'::jsonb)->>'duplicate')::boolean,
  'reenvio da resposta do pedido antigo continua idempotente');

-- --------------------------------------------------------------- permissoes
reset role;
select t.ok(not has_function_privilege('anon','public._ad_skill_attr(text)','execute')
        and not has_function_privilege('authenticated','public._ad_skill_attr(text)','execute'),
  'tabela de pares (_ad_skill_attr) nao e chamavel pela API');
select t.ok(not has_function_privilege('anon','public.master_create_request(uuid,uuid,uuid,text,jsonb,text)','execute'),
  'master_create_request segue fechada para anon');

select 'TODOS OS TESTES DA ETAPA 5 PASSARAM' as resultado;
