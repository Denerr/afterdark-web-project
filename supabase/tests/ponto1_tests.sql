\set ON_ERROR_STOP 1
-- Helpers (security invoker: rodam com o papel corrente)
create schema t;
grant usage on schema t to anon, authenticated;
create function t.ok(c boolean, msg text) returns void language plpgsql as $$
begin if c is not true then raise exception 'FALHOU: %', msg; end if; raise notice 'PASSOU: %', msg; end $$;
create function t.fails(q text, msg text, pat text default null) returns void language plpgsql as $$
begin
  begin execute q; exception when others then
    if pat is not null and sqlerrm !~ pat then raise exception 'FALHOU (erro inesperado "%"): %', sqlerrm, msg; end if;
    raise notice 'PASSOU (bloqueado: %): %', sqlerrm, msg; return;
  end;
  raise exception 'FALHOU (deveria bloquear): %', msg;
end $$;
grant execute on all functions in schema t to anon, authenticated;
create function t.v(k text) returns text language sql stable as $$ select current_setting('t.'||k) $$;
grant execute on function t.v(text) to anon, authenticated;

-- usuários: M = mestre, L = jogador logado, X = outro usuário qualquer
insert into auth.users(id) values
 ('11111111-1111-1111-1111-111111111111'),('22222222-2222-2222-2222-222222222222'),('33333333-3333-3333-3333-333333333333');

-- Mestre cria duas mesas
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa T','SV-TEST') returning id as tid \gset
insert into public.tables(name, invite_code) values ('Mesa 2','SV-TWO') returning id as tid2 \gset
select set_config('t.tid', :'tid', false), set_config('t.tid2', :'tid2', false);

-- Visitante A entra (anon)
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as ta from public.join_table_by_code('sv-test','Ana') \gset
-- Visitante B entra
select member_id as mb, member_token as tb from public.join_table_by_code('SV-TEST','Bia') \gset
select set_config('t.ma', :'ma', false), set_config('t.ta', :'ta', false), set_config('t.mb', :'mb', false), set_config('t.tb', :'tb', false);
select t.fails($$select public.join_table_by_code('NOPE','x')$$, 'código inválido', 'invalid_code');
select t.ok(length(t.v('ta')) = 64, 'token de 64 caracteres entregue no ingresso');

-- Segredo não é acessível pela API
select t.fails($$select * from public.table_member_secrets$$, 'anon não lê table_member_secrets', 'permission denied');
select t.fails($$select * from public.table_requests$$, 'anon não lê table_requests', 'permission denied');

-- Token errado / de outro membro
select t.fails(format($$select public.player_get_state(%L,'x')$$, t.v('ma')), 'token inválido', 'not_authorized');
select t.fails(format($$select public.player_get_state(%L,%L)$$, t.v('ma'), t.v('tb')), 'token de B não abre A', 'not_authorized');
select t.ok((public.player_get_state(t.v('ma')::uuid, t.v('ta'))->'member'->>'id') = t.v('ma'), 'A lê o próprio estado');

-- Proteção de campos reservados por acesso direto (políticas antigas ainda permissivas)
select t.fails(format($$update public.table_members set status='pronto' where id=%L$$, t.v('ma')), 'anon não se marca pronto direto', 'reservado');
select t.fails(format($$update public.table_members set wounds='[]'::jsonb||'{"lvl":"x"}'::jsonb where id=%L$$, t.v('mb')), 'anon não altera ferimentos', 'reservado');
select t.fails(format($$update public.table_members set approved_at=now() where id=%L$$, t.v('ma')), 'anon não se aprova', 'reservado');
insert into public.table_members(table_id, player_name, status, approved_at, sheet_ready, wounds) values (t.v('tid')::uuid,'Intruso','pronto',now(),true,'[{"lvl":"x"}]') returning id as mi \gset
select t.ok((select status='conectando' and approved_at is null and not sheet_ready and wounds='[]'::jsonb from public.table_members where id=:'mi'), 'insert direto não injeta aprovação/consequências');

-- Fichas: A e B concluem
select t.fails(format($$select public.player_submit_sheet(%L,%L,'Ana','Kara','{}'::jsonb)$$, t.v('ma'), t.v('tb')), 'B não grava ficha de A', 'not_authorized');
select public.player_submit_sheet(:'ma', :'ta', 'Ana', 'Kara', '{"attrs":{"mente":3},"skills":{"analise":2}}');
select public.player_submit_sheet(:'mb', :'tb', 'Bia', 'Rook', '{"attrs":{"corpo":2}}');
select t.ok((select status='aguardando' and sheet_ready and approved_at is null from public.table_members where id=:'ma'), 'ficha concluída != aprovada');

-- Funções de mestre negadas a anon e a outro usuário logado
select t.fails(format($$select public.master_set_approval(%L,true)$$, t.v('ma')), 'anon não aprova', 'permission denied');
reset role; set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.fails(format($$select public.master_set_approval(%L,true)$$, t.v('ma')), 'outro usuário não aprova', 'not_authorized');
select t.fails(format($$select public.master_member_consequence(%L,'add_wound','{"lvl":"leve"}')$$, t.v('ma')), 'outro usuário não fere', 'not_authorized');
select t.fails(format($$select public.master_create_request(%L,%L,gen_random_uuid(),'geral','{}')$$, t.v('tid'), t.v('ma')), 'outro usuário não envia teste', 'not_authorized');
select t.ok((select count(*) from public.table_requests)=0, 'outro usuário não vê solicitações');

-- Mestre
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
-- Guarda de início: A e B não aprovados + intruso sem ficha
select t.fails(format($$select public.master_start_session(%L)$$, t.v('tid')), 'início bloqueado sem aprovação', 'players_not_approved');
select t.fails(format($$select public.master_set_approval(%L,true)$$, :'mi'), 'não aprova sem ficha', 'sheet_not_ready');
delete from public.table_members where id=:'mi';
select public.master_set_approval(:'ma', true);
select t.fails(format($$select public.master_start_session(%L)$$, t.v('tid')), 'início bloqueado com B pendente', 'players_not_approved');
select public.master_set_approval(:'mb', true);
select t.ok((select status='pronto' and approved_at is not null from public.table_members where id=:'mb'), 'aprovação persistida');
select t.ok((public.master_start_session(:'tid')->>'ok')::boolean, 'início liberado com todos aprovados');
select t.fails(format($$select public.master_start_session(%L)$$, t.v('tid2')), 'mesa sem jogadores não inicia', 'no_players');

-- Mestre envia dois testes para A e um para B; retry com a mesma chave não duplica
select (public.master_create_request(:'tid', :'ma', 'aaaaaaaa-0000-0000-0000-000000000001', 'geral', '{"label":"Mente + Análise","attrKey":"mente","skillKey":"analise","difficulty":15}'))->>'id' as r1 \gset
select t.ok((public.master_create_request(:'tid', :'ma', 'aaaaaaaa-0000-0000-0000-000000000001', 'geral', '{"label":"dup"}')->>'duplicate')::boolean, 'retry do envio não duplica');
select (public.master_create_request(:'tid', :'ma', 'aaaaaaaa-0000-0000-0000-000000000002', 'combate', '{"label":"Ataque","difficulty":13,"danoBase":2}'))->>'id' as r2 \gset
select (public.master_create_request(:'tid', :'mb', 'aaaaaaaa-0000-0000-0000-000000000003', 'geral', '{"label":"Teste B"}'))->>'id' as r3 \gset
select set_config('t.r1', :'r1', false), set_config('t.r3', :'r3', false);
select t.ok((select count(*) from public.table_requests where table_id=:'tid')=3, 'mestre vê 3 solicitações (sem duplicata)');
select t.fails(format($$select public.master_create_request(%L,%L,gen_random_uuid(),'geral','{}')$$, t.v('tid2'), t.v('ma')), 'alvo de outra mesa bloqueado', 'target_not_in_table');

-- Jogadores: cada um recebe só as suas
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.ok(jsonb_array_length(public.player_get_state(t.v('ma')::uuid,t.v('ta'))->'requests')=2, 'A recebe 2 testes');
select t.ok(jsonb_array_length(public.player_get_state(t.v('mb')::uuid,t.v('tb'))->'requests')=1, 'B recebe só o seu');
select t.ok(not (public.player_get_state(t.v('mb')::uuid,t.v('tb'))::text like '%Mente + Análise%'), 'B não vê teste de A');
select t.fails(format($$select public.player_answer_request(%L,%L,%L,'{"grade":"x"}')$$, t.v('mb'), t.v('tb'), t.v('r1')), 'B não responde teste de A', 'request_not_found');

-- A responde r1; repetir não duplica nem sobrescreve
select t.ok(not (public.player_answer_request(:'ma', :'ta', :'r1', '{"dice":[12,5,18],"max":18,"bonus":2,"total":20,"diff":15,"grade":"Sucesso Completo"}')->>'duplicate')::boolean, 'A responde r1');
select t.ok((public.player_answer_request(:'ma', :'ta', :'r1', '{"grade":"Desastre"}')->>'duplicate')::boolean, 'segunda resposta marcada como duplicata');
reset role; select t.ok((select result->>'grade' from public.table_requests where id=:'r1')='Sucesso Completo', 'resultado original preservado');
select t.ok((select status from public.table_requests where id=:'r2')='pendente', 'r2 de A continua pendente (sem sobrescrita)');

-- Mestre processa o resultado uma única vez; cancela r3
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.ok(public.master_ack_request(:'r1'), 'primeiro ack = true');
select t.ok(not public.master_ack_request(:'r1'), 'segundo ack = false (sem log duplicado)');
select t.ok(public.master_cancel_request(:'r3'), 'mestre cancela r3');
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.fails(format($$select public.player_answer_request(%L,%L,%L,'{"grade":"x"}')$$, t.v('mb'), t.v('tb'), t.v('r3')), 'resposta a teste cancelado', 'request_cancelled');

-- Consequências
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select public.master_member_consequence(:'ma','add_wound','{"lvl":"moderado","desc":"Costela trincada","op":"op-1"}');
select public.master_member_consequence(:'ma','add_wound','{"lvl":"moderado","desc":"Costela trincada","op":"op-1"}');
select t.ok((select jsonb_array_length(wounds) from public.table_members where id=:'ma')=1, 'retry do ferimento (mesma op) não duplica');
select public.master_member_consequence(:'ma','add_condition','{"name":"Abalado"}');
select public.master_member_consequence(:'ma','add_condition','{"name":"Abalado"}');
select t.ok((select conditions from public.table_members where id=:'ma')='["Abalado"]'::jsonb, 'condição não duplica');
select t.ok((select wounds='[]'::jsonb and conditions='[]'::jsonb from public.table_members where id=:'mb'), 'B não recebe consequências de A');
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.ok((public.player_get_state(t.v('ma')::uuid,t.v('ta'))->'member'->'wounds'->0->>'lvl')='moderado', 'ficha de A mostra o ferimento');
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select (wounds->0->>'id') as wid from public.table_members where id=:'ma' \gset
select public.master_member_consequence(:'ma','remove_wound',jsonb_build_object('id',:'wid'));
select public.master_member_consequence(:'ma','remove_condition','{"name":"Abalado"}');
select t.ok((select wounds='[]'::jsonb and conditions='[]'::jsonb from public.table_members where id=:'ma'), 'remoção persistida');

-- Jogador logado: autorizado por auth.uid() sem token; outro logado não
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
select member_id as ml from public.join_table_by_code('SV-TEST','Leo') \gset
select t.ok((select user_id from public.table_members where id=:'ml')='22222222-2222-2222-2222-222222222222', 'user_id vem do auth.uid() (não do cliente)');
select t.ok((public.player_get_state(:'ml', null)->'member'->>'id')=:'ml', 'logado lê o próprio estado sem token');
select set_config('t.ml', :'ml', false);
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.fails(format($$select public.player_get_state(%L,null)$$, t.v('ml')), 'outro logado não lê', 'not_authorized');

-- Prontidão: desmarcar zera aprovação
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select public.player_set_ready(:'mb', :'tb', false);
reset role;
select t.ok((select status='escolhendo' and approved_at is null and not sheet_ready from public.table_members where id=:'mb'), 'desmarcar prontidão zera aprovação');

-- Grants: helpers internos fechados
select t.ok(not has_function_privilege('anon','public._ad_member_ok(uuid,text)','execute'), 'helper _ad_member_ok fechado p/ anon');
select t.ok(not has_function_privilege('authenticated','public._ad_is_owner(uuid)','execute'), 'helper _ad_is_owner fechado p/ authenticated');
select t.ok(not has_function_privilege('anon','public.master_start_session(uuid)','execute'), 'master_* fechado p/ anon');
\echo 'TODOS OS TESTES SQL PASSARAM'
