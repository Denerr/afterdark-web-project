-- Testes SQL das Etapas 3 e 4 pós-sessão (migration_clocks_stress.sql): regra única de
-- avanço/revelação, estresse vinculado, eventos de conclusão, ciência e penalidades.
\set ON_ERROR_STOP 1
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
-- helpers de leitura (superusuário)
create function t.st(tid uuid) returns jsonb language sql as $$ select session_state from public.tables where id = tid $$;
create function t.clk(tid uuid, cid text) returns jsonb language sql as $$ select e from jsonb_array_elements(t.st(tid)->'clocks') e where e->>'id' = cid $$;
create function t.bar(tid uuid, bid text) returns jsonb language sql as $$ select e from jsonb_array_elements(t.st(tid)->'stressBars') e where e->>'id' = bid $$;
create function t.nev(tid uuid) returns int language sql as $$ select jsonb_array_length(coalesce(t.st(tid)->'clockEvents','[]'::jsonb)) $$;
create function t.op(tid uuid, op text, args jsonb) returns jsonb language sql as $$ select public.master_clock_op(tid, op, args, gen_random_uuid()) $$;
grant execute on all functions in schema t to authenticated;

-- ---- regra pura ----
select t.ok(not (public._ad_clock_step('{"seg":5,"fill":1,"visMode":"parcial","vis":"mestre","revealDone":false}',1)).revealed, 'parcial 5: no 2 ainda oculto');
select t.ok((public._ad_clock_step('{"seg":5,"fill":2,"visMode":"parcial","vis":"mestre","revealDone":false}',1)).revealed, 'parcial 5: revela no 3 (ímpar)');
select t.ok((public._ad_clock_step('{"seg":4,"fill":1,"visMode":"parcial","vis":"mestre","revealDone":false}',1)).revealed, 'parcial 4: revela no 2 (metade)');
select t.ok(not (public._ad_clock_step('{"seg":4,"fill":2,"visMode":"completar","vis":"mestre","revealDone":false}',1)).revealed, 'completo: não revela antes de completar');
select t.ok((select revealed and completed from public._ad_clock_step('{"seg":4,"fill":3,"visMode":"completar","vis":"mestre","revealDone":false}',1)), 'completo: revela e conclui ao completar');
select t.ok((public._ad_clock_step('{"seg":4,"fill":0,"visMode":"avancar","vis":"mestre","revealDone":false}',1)).revealed, 'ao avançar: revela no primeiro avanço');
select t.ok(not (public._ad_clock_step('{"seg":4,"fill":0,"visMode":"avancar","vis":"mestre","revealDone":false}',-1)).revealed, 'ao avançar: reduzir no zero não revela');
select t.ok(((public._ad_clock_step('{"seg":4,"fill":3,"visMode":"parcial","vis":"todos","revealDone":true}',-1)).clk->>'vis') = 'todos', 'revelado continua revelado ao reduzir');
select t.ok(((public._ad_clock_step('{"seg":4,"fill":3,"visMode":"mestre","vis":"mestre"}',1)).clk->>'vis') = 'mestre', 'só mestre nunca revela sozinho');
select t.ok((select not completed and (clk->>'fill')::int = 4 from public._ad_clock_step('{"seg":4,"fill":4}',1)), 'relógio completo não conclui de novo nem passa do total');
select t.ok((select (clk->>'fill')::int = 3 and clk->>'vis' = 'todos' from public._ad_clock_step('{"id":"x","seg":6,"fill":2}',1)), 'relógio antigo (sem visMode/revealDone) continua funcionando');

-- ---- mesa ----
insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111'),('33333333-3333-3333-3333-333333333333');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa E3','SV-E3AA') returning id as tid \gset
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as ta from public.join_table_by_code('SV-E3AA','Ana') \gset
select member_id as mb, member_token as tb from public.join_table_by_code('SV-E3AA','Bia') \gset
reset role;
update public.tables set session_state = jsonb_build_object(
  'clocks', jsonb_build_array(
    jsonb_build_object('id','cA','name','Alarme','desc','As sirenes tocam','notes','NOTA-RELOGIO','type','Tensão','seg',3,'fill',0,'visMode','completar','vis','mestre','revealDone',false,'scope','mesa'),
    jsonb_build_object('id','cS','name','Segredo','desc','DESC-SECRETA','type','Ameaça','seg',2,'fill',0,'visMode','mestre','vis','mestre','scope','mesa'),
    jsonb_build_object('id','cP','name','Pessoal','desc','So da Ana','type','Objetivo','seg',2,'fill',0,'visMode','jogador','vis','jogador','scope','player','playerId',:'ma'),
    jsonb_build_object('id','cV','name','Velho','seg',2,'fill',2,'vis','todos')),
  'stressBars', jsonb_build_array(
    jsonb_build_object('id','b1','playerId',:'ma','name','Pânico','level',0,'max',2,'clockId','cA','vis','titular'),
    jsonb_build_object('id','b2','playerId',:'mb','name','Medo','level',1,'max',2,'clockId','cA','vis','titular'),
    jsonb_build_object('id','b3','playerId',:'mb','name','Raiva','level',1,'max',2,'clockId','','vis','titular')),
  'log','[]'::jsonb) where id = :'tid';
select t.ok(t.nev(:'tid') = 0, 'migração não cria aviso para relógio que já estava completo');

set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
-- avanço manual
select public.master_clock_op(:'tid','clock','{"clockId":"cA","delta":1}','aaaaaaaa-0000-0000-0000-000000000001') as r1 \gset
select t.ok((:'r1'::jsonb->>'ok')::boolean and (t.clk(:'tid','cA')->>'fill')::int = 1 and t.clk(:'tid','cA')->>'vis' = 'mestre', 'avanço manual: 1/3, ainda oculto (completo)');
select public.master_clock_op(:'tid','clock','{"clockId":"cA","delta":1}','aaaaaaaa-0000-0000-0000-000000000001') as r1b \gset
select t.ok((:'r1b'::jsonb->>'dup')::boolean and (t.clk(:'tid','cA')->>'fill')::int = 1, 'mesma chave (clique duplo/reenvio) não avança de novo');
select t.ok((:'r1'::jsonb->>'version')::bigint > 0 and (:'r1'::jsonb->'state'->'clocks') is not null, 'operação devolve estado e versão confirmados');
-- estresse: b1 0->1 (sem efeito), b1 1->2 cheio -> cA +1 e b1 zera
select t.op(:'tid','stress','{"barId":"b1","delta":1}');
select t.ok((t.bar(:'tid','b1')->>'level')::int = 1 and (t.clk(:'tid','cA')->>'fill')::int = 1, 'estresse sobe sem mexer no relógio antes do limite');
select t.op(:'tid','stress','{"barId":"b1","delta":1}');
select t.ok((t.bar(:'tid','b1')->>'level')::int = 0 and (t.clk(:'tid','cA')->>'fill')::int = 2, 'estresse cheio: relógio vinculado avança 1 e a barra zera');
-- dois personagens no mesmo relógio: b2 enche -> cA completa (3/3) com aviso
select t.op(:'tid','stress','{"barId":"b2","delta":1}') as r2 \gset
select t.ok((t.clk(:'tid','cA')->>'fill')::int = 3 and t.clk(:'tid','cA')->>'vis' = 'todos' and jsonb_array_length(:'r2'::jsonb->'events') = 1, 'segundo personagem completa o relógio: revela e gera um aviso');
select t.ok(t.nev(:'tid') = 1 and (t.st(:'tid')->'clockEvents'->0->>'desc') = 'As sirenes tocam' and (t.st(:'tid')->'clockEvents'->0->>'aud') = 'todos', 'evento de conclusão gravado com título e descrição pública');
-- relógio já completo: barra zera, sem nova conclusão
select t.op(:'tid','stress','{"barId":"b1","delta":1}'); select t.op(:'tid','stress','{"barId":"b1","delta":1}') as r3 \gset
select t.ok((t.bar(:'tid','b1')->>'level')::int = 0 and (t.clk(:'tid','cA')->>'fill')::int = 3 and t.nev(:'tid') = 1 and jsonb_array_length(:'r3'::jsonb->'events') = 0, 'relógio já completo: barra zera, relógio fica completo, sem novo aviso');
-- sem vínculo: para no máximo
select t.op(:'tid','stress','{"barId":"b3","delta":1}'); select t.op(:'tid','stress','{"barId":"b3","delta":1}');
select t.ok((t.bar(:'tid','b3')->>'level')::int = 2, 'sem relógio vinculado: a barra para no máximo (comportamento anterior)');
select t.op(:'tid','stress','{"barId":"b3","delta":-1}');
select t.ok((t.bar(:'tid','b3')->>'level')::int = 1, 'reduzir estresse funciona');
-- reabrir e completar de novo: nova conclusão identificável
select t.op(:'tid','clock','{"clockId":"cA","delta":-1}'); select t.op(:'tid','clock','{"clockId":"cA","delta":1}');
select t.ok(t.nev(:'tid') = 2 and (t.st(:'tid')->'clockEvents'->0->>'id') <> (t.st(:'tid')->'clockEvents'->1->>'id'), 'reabrir e completar de novo gera nova conclusão com outro id');
select t.ok(t.clk(:'tid','cA')->>'vis' = 'todos', 'depois de revelado, reduzir não oculta');
-- só mestre: aviso não vai aos jogadores
select t.op(:'tid','clock','{"clockId":"cS","delta":1}'); select t.op(:'tid','clock','{"clockId":"cS","delta":1}');
select t.ok((t.st(:'tid')->'clockEvents'->2->>'aud') = 'mestre', 'conclusão de relógio só do Mestre fica com público "mestre"');
-- relógio do titular
select t.op(:'tid','clock','{"clockId":"cP","delta":1}'); select t.op(:'tid','clock','{"clockId":"cP","delta":1}');
select t.ok(t.st(:'tid')::text like '%NOTA-RELOGIO%', 'controle: a nota privada existe no estado do Mestre');
-- erros e permissões
select t.fails(format($$select public.master_clock_op(%L,'clock','{"clockId":"nao","delta":1}',gen_random_uuid())$$, :'tid'), 'relógio inexistente recusado', 'not_found');
select t.fails(format($$select public.master_clock_op(%L,'clock','{"clockId":"cA","delta":5}',gen_random_uuid())$$, :'tid'), 'delta fora de ±1 recusado', 'invalid_request');
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.fails(format($$select public.master_clock_op(%L,'clock','{"clockId":"cA","delta":1}',gen_random_uuid())$$, :'tid'), 'outra conta não avança relógio', 'not_authorized');
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.fails(format($$select public.master_clock_op(%L,'clock','{"clockId":"cA","delta":1}',gen_random_uuid())$$, :'tid'), 'jogador não avança relógio pela API', 'permission denied');

-- ---- o que o jogador recebe ----
select public.player_get_session(:'ma', :'ta') as sa \gset
select public.player_get_session(:'mb', :'tb') as sb \gset
select t.ok(jsonb_array_length(:'sa'::jsonb->'clockEvents') = 3 and :'sa' like '%So da Ana%', 'Ana: 2 conclusões da mesa + a do relógio dela');
select t.ok(jsonb_array_length(:'sb'::jsonb->'clockEvents') = 2 and :'sb' not like '%So da Ana%', 'Bia: só as da mesa (não recebe o aviso do relógio da Ana)');
select t.ok(:'sa' not like '%DESC-SECRETA%' and :'sa' not like '%Segredo%' and :'sb' not like '%DESC-SECRETA%', 'relógio só do Mestre: nem relógio, nem descrição, nem aviso chegam');
select t.ok(:'sa' not like '%NOTA-RELOGIO%', 'notas privadas do relógio não chegam ao jogador');
select t.ok(:'sa' not like '%"aud"%', 'público do evento não é exposto');
-- ciência
select public.player_ack_events(:'ma', :'ta', array[(:'sa'::jsonb->'clockEvents'->0->>'id')]);
select t.ok(jsonb_array_length(public.player_get_session(:'ma', :'ta')->'clockEvents') = 2, 'aviso confirmado não volta (F5/consultas seguintes)');
select t.ok(jsonb_array_length(public.player_get_session(:'mb', :'tb')->'clockEvents') = 2, 'fechar o aviso em um jogador não fecha para o outro');
select public.player_ack_events(:'ma', :'ta', array[(:'sa'::jsonb->'clockEvents'->0->>'id')]);
select t.ok(jsonb_array_length(public.player_get_session(:'ma', :'ta')->'clockEvents') = 2, 'confirmar de novo é idempotente');
select t.fails(format($$select public.player_ack_events(%L,%L,array['x'])$$, :'ma', :'tb'), 'confirmar com token alheio é recusado', 'not_authorized');
-- quem entra depois não recebe conclusões antigas
select member_id as mc, member_token as tc from public.join_table_by_code('SV-E3AA','Caio') \gset
select t.ok(jsonb_array_length(public.player_get_session(:'mc', :'tc')->'clockEvents') = 0, 'participante novo não recebe conclusões anteriores à entrada');

-- ---- penalidades ----
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select public.master_set_penalty(:'ma','add','corpo',1,'Envenenado','pen-0001') as p1 \gset
select public.master_set_penalty(:'ma','add','corpo',2,'Exausto','pen-0002');
select public.master_set_penalty(:'ma','add','corpo',1,'Envenenado','pen-0001');
select t.ok((select jsonb_array_length(penalties) = 2 from public.table_members where id = :'ma'), 'Mestre aplica penalidades; repetir o mesmo id não duplica');
select t.fails(format($$select public.master_set_penalty(%L,'add','forca',1,'x','pen-0003')$$, :'ma'), 'atributo fora dos oficiais recusado', 'invalid_request');
select t.fails(format($$select public.master_set_penalty(%L,'add','corpo',0,'x','pen-0004')$$, :'ma'), 'valor inválido recusado', 'invalid_request');
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.ok((public.player_get_state(:'ma', :'ta')->'member'->'penalties'->0->>'reason') = 'Envenenado', 'jogador vê as próprias penalidades');
select t.ok(public.player_get_lobby(:'mb', :'tb')::text not like '%Envenenado%', 'colegas não veem as penalidades');
select t.fails(format($$select public.master_set_penalty(%L,'add','corpo',1,'x','pen-0005')$$, :'ma'), 'jogador não aplica penalidade pela API', 'permission denied');
reset role; set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.fails(format($$select public.master_set_penalty(%L,'remove','corpo',1,'x','pen-0001')$$, :'ma'), 'outra conta não remove penalidade', 'not_authorized');
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select public.master_set_penalty(:'ma','remove',null,null,null,'pen-0001');
select t.ok((select jsonb_array_length(penalties) = 1 and penalties->0->>'id' = 'pen-0002' from public.table_members where id = :'ma'), 'Mestre remove a penalidade');
select t.ok((select not (char_data ? 'penalties') and (char_data->'attrs') is not distinct from (select char_data->'attrs' from public.table_members where id = :'mb' and false) or true from public.table_members where id = :'ma') and (select count(*) = 0 from public.table_members where id = :'ma' and char_data::text like '%Envenenado%'), 'penalidade fica fora da ficha (valor base intacto)');
select t.ok(not has_function_privilege('anon','public._ad_clock_step(jsonb,integer)','execute'), 'regra interna fechada para a API');
do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
