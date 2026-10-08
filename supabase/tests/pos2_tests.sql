-- Testes SQL da Etapa 2 pós-sessão (migration_scenes.sql): o que o jogador recebe de
-- NPCs, pistas e cenas.
\set ON_ERROR_STOP 1
create schema t;
grant usage on schema t to anon, authenticated;
create function t.ok(c boolean, msg text) returns void language plpgsql as $$
begin if c is not true then raise exception 'FALHOU: %', msg; end if; raise notice 'PASSOU: %', msg; end $$;
grant execute on all functions in schema t to anon, authenticated;

insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa E2','SV-E2AA') returning id as tid \gset
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as ta from public.join_table_by_code('SV-E2AA','Ana') \gset
reset role;
update public.tables set session_state = jsonb_build_object(
  'npcs', jsonb_build_array(
     jsonb_build_object('id','n1','name','Madame Rubra','desc','Leiloeira','notes','SEGREDO-NPC','reveal',3,'theme','vampire'),
     jsonb_build_object('id','n2','name','Vulto','desc','?','notes','SEGREDO-NPC2','reveal',1,'theme','human')),
  'clues', jsonb_build_array(
     jsonb_build_object('id','k1','name','Bilhete','txt','Cais 7','notes','SEGREDO-PISTA','status','compartilhada'),
     jsonb_build_object('id','k2','name','Cofre','txt','OCULTO-TXT','notes','x','status','oculta')),
  'scenes', jsonb_build_array(
     jsonb_build_object('id','s1','title','Leilão','desc','Salão cheio','notes','SEGREDO-CENA','mapId','saint-vesper','shared',true,
        'present', jsonb_build_array(jsonb_build_object('kind','pc','id',:'ma'),jsonb_build_object('kind','npc','id','n1'),
                                     jsonb_build_object('kind','npc','id','n2'),jsonb_build_object('kind','pc','id','00000000-0000-0000-0000-000000000000'),
                                     jsonb_build_object('kind','npc','id','removido'))),
     jsonb_build_object('id','s2','title','CENA-PRIVADA','desc','x','shared',false,'present','[]'::jsonb)),
  'activeSceneId','s1') where id = :'tid';

set role anon; select set_config('request.jwt.claim.sub','',false);
select public.player_get_session(:'ma', :'ta') as st \gset
select t.ok(:'st' not like '%SEGREDO-NPC%' and :'st' not like '%SEGREDO-PISTA%' and :'st' not like '%SEGREDO-CENA%', 'notas privadas de NPC, pista e cena não chegam ao jogador');
select t.ok(:'st' like '%Madame Rubra%' and :'st' not like '%Vulto%', 'NPC revelado chega; não revelado não');
select t.ok(:'st' like '%Cais 7%' and :'st' not like '%OUTRO%' and :'st' not like '%OCULTO-TXT%', 'pista compartilhada chega; oculta não');
select t.ok(:'st' not like '%CENA-PRIVADA%' and (:'st'::jsonb ? 'scenes') = false and (:'st'::jsonb ? 'activeSceneId') = false, 'lista de cenas não chega ao jogador');
select t.ok((:'st'::jsonb->'activeScene'->>'title') = 'Leilão' and (:'st'::jsonb->'activeScene'->>'mapId') = 'saint-vesper', 'cena ativa compartilhada chega com título e mapa');
select t.ok((:'st'::jsonb->'activeScene'->'presentPcs') = jsonb_build_array(:'ma') , 'presentes: só participantes que existem na mesa');
select t.ok((:'st'::jsonb->'activeScene'->'presentNpcs') = '["n1"]'::jsonb and (:'st'::jsonb->'activeScene'->>'presentUnknown')::int = 1, 'presentes: NPC revelado por id; não revelado só como contagem; removido ignorado');
reset role;
update public.tables set session_state = jsonb_set(session_state,'{activeSceneId}','"s2"') where id = :'tid';
set role anon;
select t.ok((public.player_get_session(:'ma', :'ta')->'activeScene') = 'null'::jsonb, 'cena ativa não compartilhada não chega');
reset role;
update public.tables set session_state = session_state - 'activeSceneId' where id = :'tid';
set role anon;
select t.ok((public.player_get_session(:'ma', :'ta')->'activeScene') = 'null'::jsonb, 'sem cena ativa: activeScene nulo');
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.ok((public.master_get_session(:'tid')->'state')::text like '%SEGREDO-CENA%', 'Mestre continua recebendo tudo (notas e cenas)');
do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
