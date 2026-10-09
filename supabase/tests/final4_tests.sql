-- Testes SQL da Etapa 4 do plano final (migration_final_scenes_maps.sql): mapa ativo
-- independente da cena e imagem da cena.
\set ON_ERROR_STOP 1
create schema t;
grant usage on schema t to anon, authenticated;
create function t.ok(c boolean, msg text) returns void language plpgsql as $$
begin if c is not true then raise exception 'FALHOU: %', msg; end if; raise notice 'PASSOU: %', msg; end $$;
grant execute on all functions in schema t to anon, authenticated;
insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa F4','SV-F4AA') returning id as tid \gset
select (public.master_media_upload('scene','Salão','data:image/jpeg;base64,/9j/SALAO',10,10)->>'id') as img \gset
select (public.master_media_upload('scene','Privada','data:image/jpeg;base64,/9j/PRIV',10,10)->>'id') as img2 \gset
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as ta from public.join_table_by_code('SV-F4AA','Ana') \gset
reset role;
update public.tables set session_state = jsonb_build_object(
  'scenes', jsonb_build_array(
    jsonb_build_object('id','s1','title','Salão','desc','Lustres','imageId',:'img','mapId','gota-academia-1','shared',true),
    jsonb_build_object('id','s2','title','Privada','imageId',:'img2','shared',false)),
  'activeSceneId','s1','activeMapId','gota-academia-2') where id = :'tid';
set role anon;
select public.player_get_session(:'ma', :'ta') as st \gset
select t.ok((:'st'::jsonb->>'activeMapId') = 'gota-academia-2', 'mapa ativo chega ao jogador, independente do mapa associado à cena');
select t.ok((:'st'::jsonb->'activeScene'->>'imageId') = :'img' and (:'st'::jsonb->'activeScene'->>'mapId') = 'gota-academia-1', 'cena ativa traz a imagem própria e a associação de mapa');
select t.ok((public.player_media(:'ma', :'ta', array[:'img'::uuid])->>:'img') like 'data:image/jpeg%', 'imagem da cena ativa compartilhada é entregue');
select t.ok(public.player_media(:'ma', :'ta', array[:'img2'::uuid]) = '{}'::jsonb and :'st' not like '%' || :'img2' || '%', 'imagem de cena não ativa/privada não é entregue nem citada');
reset role; update public.tables set session_state = session_state - 'activeMapId' where id = :'tid'; set role anon;
select t.ok((public.player_get_session(:'ma', :'ta')->'activeMapId') = 'null'::jsonb, 'sem mapa ativo: nada é inventado');
do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
