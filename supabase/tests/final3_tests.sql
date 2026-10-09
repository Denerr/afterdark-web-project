-- Testes SQL da Etapa 3 do plano final (migration_final_clocks.sql): aviso de revelação
-- separado da conclusão, imagem do aviso e retenção de 14 dias.
\set ON_ERROR_STOP 1
create schema t;
grant usage on schema t to anon, authenticated;
create function t.ok(c boolean, msg text) returns void language plpgsql as $$
begin if c is not true then raise exception 'FALHOU: %', msg; end if; raise notice 'PASSOU: %', msg; end $$;
grant execute on all functions in schema t to anon, authenticated;
create function t.evs(tid uuid) returns jsonb language sql as $$ select coalesce(session_state->'clockEvents','[]'::jsonb) from public.tables where id = tid $$;
create function t.op(tid uuid, op text, args jsonb) returns jsonb language sql as $$ select public.master_clock_op(tid, op, args, gen_random_uuid()) $$;
create function t.kinds(tid uuid, cid text) returns text language sql as $$
  select coalesce(string_agg(e->>'kind', ',' order by o), '') from jsonb_array_elements(t.evs(tid)) with ordinality as x(e, o) where e->>'clockId' = cid $$;
grant execute on all functions in schema t to authenticated;

insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa F3','SV-F3AA') returning id as tid \gset
select (public.master_media_upload('clock','Sirenes','data:image/jpeg;base64,/9j/SIRENE',10,10)->>'id') as img \gset
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as ta from public.join_table_by_code('SV-F3AA','Ana') \gset
reset role;
update public.tables set session_state = jsonb_build_object(
  'clocks', jsonb_build_array(
    jsonb_build_object('id','cP','name','Parcial','type','Tensão','seg',4,'fill',0,'visMode','parcial','vis','mestre','revealDone',false,'scope','mesa'),
    jsonb_build_object('id','cV','name','Avanco','type','Ameaça','seg',3,'fill',0,'visMode','avancar','vis','mestre','revealDone',false,'scope','mesa'),
    jsonb_build_object('id','cC','name','Completo','desc','As sirenes tocam','imageId',:'img','type','Tensão','seg',2,'fill',0,'visMode','completar','vis','mestre','revealDone',false,'scope','mesa'),
    jsonb_build_object('id','cT','name','Publico','type','Objetivo','seg',1,'fill',0,'visMode','todos','vis','todos','revealDone',true,'scope','mesa'),
    jsonb_build_object('id','cS','name','Secreto','type','Ameaça','seg',1,'fill',0,'visMode','mestre','vis','mestre','scope','mesa'),
    jsonb_build_object('id','cE','name','Estresse','type','Tensão','seg',2,'fill',0,'visMode','parcial','vis','mestre','revealDone',false,'scope','mesa')),
  'stressBars', jsonb_build_array(jsonb_build_object('id','b1','playerId',:'ma','name','Pânico','level',0,'max',1,'clockId','cE','vis','titular')),
  'clockEvents', (select jsonb_agg(jsonb_build_object('id','old'||g,'kind','complete','clockId','x','name','Antigo'||g,'aud','todos','at', now() - interval '1 hour')) from generate_series(1,50) g)
     || jsonb_build_array(jsonb_build_object('id','velho','kind','complete','clockId','x','name','Vencido','aud','todos','at', now() - interval '20 days')),
  'log','[]'::jsonb) where id = :'tid';
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);

-- Parcial
select t.op(:'tid','clock','{"clockId":"cP","delta":1}');
select t.ok(t.kinds(:'tid','cP') = '', 'parcial antes da metade: sem aviso');
select t.op(:'tid','clock','{"clockId":"cP","delta":1}') as rp \gset
select t.ok(t.kinds(:'tid','cP') = 'reveal' and (:'rp'::jsonb->'events'->0->>'fill')::int = 2 and (:'rp'::jsonb->'events'->0->>'seg')::int = 4, 'parcial na metade: aviso "revelado" com progresso público');
select t.op(:'tid','clock','{"clockId":"cP","delta":1}'); select t.op(:'tid','clock','{"clockId":"cP","delta":1}');
select t.ok(t.kinds(:'tid','cP') = 'reveal,complete', 'parcial ao completar: aviso de conclusão (sem repetir a revelação)');
-- Ao avançar
select t.op(:'tid','clock','{"clockId":"cV","delta":1}');
select t.ok(t.kinds(:'tid','cV') = 'reveal', 'ao avançar: aviso de revelação no primeiro avanço');
select t.op(:'tid','clock','{"clockId":"cV","delta":1}');
select t.ok(t.kinds(:'tid','cV') = 'reveal', 'ao avançar: avanços seguintes não repetem o aviso');
-- Completo (oculto)
select t.op(:'tid','clock','{"clockId":"cC","delta":1}');
select t.ok(t.kinds(:'tid','cC') = '', 'completo: oculto e sem aviso antes de completar');
select public.master_clock_op(:'tid','clock','{"clockId":"cC","delta":1}','bbbbbbbb-0000-0000-0000-000000000001') as rc \gset
select t.ok(t.kinds(:'tid','cC') = 'complete', 'completo ao completar: UM aviso (conclusão, que já revela)');
select public.master_clock_op(:'tid','clock','{"clockId":"cC","delta":1}','bbbbbbbb-0000-0000-0000-000000000001');
select t.ok(t.kinds(:'tid','cC') = 'complete', 'reenvio com a mesma chave não duplica o aviso');
select t.ok((:'rc'::jsonb->'events'->0->>'imageId') = :'img' and (:'rc'::jsonb->'events'->0->>'desc') = 'As sirenes tocam', 'aviso guarda a imagem e a descrição da conclusão');
-- editar o relógio depois não muda o aviso pendente
reset role;
update public.tables set session_state = jsonb_set(session_state, '{clocks,2}', (session_state->'clocks'->2) || '{"desc":"EDITADO","imageId":null}') where id = :'tid';
set role authenticated;
select t.ok((select e->>'desc' = 'As sirenes tocam' and e->>'imageId' = :'img' from jsonb_array_elements(t.evs(:'tid')) e where e->>'clockId' = 'cC'), 'editar o relógio não altera o aviso já registrado');
-- público completa: só conclusão; secreto: público "mestre"
select t.op(:'tid','clock','{"clockId":"cT","delta":1}');
select t.ok(t.kinds(:'tid','cT') = 'complete', 'relógio público que completa: só o aviso de conclusão');
select t.op(:'tid','clock','{"clockId":"cS","delta":1}');
select t.ok((select e->>'aud' from jsonb_array_elements(t.evs(:'tid')) e where e->>'clockId' = 'cS') = 'mestre', 'relógio só do Mestre: aviso fica com o Mestre');
-- estresse revela pela mesma regra
select t.op(:'tid','stress','{"barId":"b1","delta":1}');
select t.ok(t.kinds(:'tid','cE') = 'reveal', 'estresse que leva o Parcial à metade gera o mesmo aviso de revelação');
-- retenção
select t.ok(jsonb_array_length(t.evs(:'tid')) > 40 and not exists(select 1 from jsonb_array_elements(t.evs(:'tid')) e where e->>'id' = 'velho') and exists(select 1 from jsonb_array_elements(t.evs(:'tid')) e where e->>'id' = 'old1'), 'retenção: mais de 40 avisos mantidos; vencidos (>14 dias) removidos');

-- jogador
reset role; set role anon;
select public.player_get_session(:'ma', :'ta') as ps \gset
select t.ok((select count(*) from jsonb_array_elements(:'ps'::jsonb->'clockEvents') e where e->>'kind' = 'reveal') = 3, 'jogador recebe os avisos de revelação');
select t.ok((select e->>'imageId' = :'img' and e->>'kind' = 'complete' from jsonb_array_elements(:'ps'::jsonb->'clockEvents') e where e->>'clockId' = 'cC'), 'jogador recebe o aviso de conclusão com a imagem');
select t.ok(:'ps' not like '%Secreto%' and :'ps' not like '%Vencido%', 'aviso só do Mestre e aviso vencido não chegam');
select t.ok((public.player_media(:'ma', :'ta', array[:'img'::uuid])->>:'img') like 'data:image/jpeg%', 'imagem do aviso entregue ao destinatário');
do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
