-- Testes SQL da Etapa 2 do plano final (migration_final_media.sql): acervo de imagens,
-- retrato de NPC por nível de revelação e diálogo.
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
insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111'),('33333333-3333-3333-3333-333333333333');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select (public.master_media_upload('npc','Rubra','data:image/webp;base64,UklGRAAA',10,10)->>'id') as m1 \gset
select (public.master_media_upload('npc','Vulto','data:image/webp;base64,VVVVVVVV',10,10)->>'id') as m2 \gset
select (public.master_media_upload('scene','Salão','data:image/jpeg;base64,/9j/SALAO',10,10)->>'id') as m3 \gset
select t.fails($$select public.master_media_upload('npc','x','https://exemplo.com/a.png',1,1)$$, 'URL externa recusada', 'media_invalid');
select t.fails($$select public.master_media_upload('npc','x','data:image/svg+xml;base64,PHN2Zz4=',1,1)$$, 'SVG recusado', 'media_invalid');
select t.fails($$select public.master_media_upload('npc','x','data:image/png;base64,'||repeat('A',700001),1,1)$$, 'imagem grande demais recusada', 'media_too_large');
select t.ok(jsonb_array_length(public.master_media_list('npc')) = 2 and public.master_media_list(null)::text not like '%UklGR%', 'acervo lista por tipo, sem o conteúdo');
select t.ok((public.master_media_get(array[:'m1'::uuid])->>:'m1') like 'data:image/webp%', 'Mestre lê a própria imagem');
insert into public.tables(name, invite_code) values ('Mesa F2','SV-F2AA') returning id as tid \gset
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.ok(jsonb_array_length(public.master_media_list(null)) = 0 and public.master_media_get(array[:'m1'::uuid]) = '{}'::jsonb, 'outra conta não lista nem lê o acervo alheio');
select t.ok(not (public.master_media_delete(:'m1')->>'ok')::boolean, 'outra conta não apaga imagem alheia');
select (public.master_media_upload('npc','Alheia','data:image/webp;base64,ALHEIA',1,1)->>'id') as mx \gset
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.fails($$select public.master_media_upload('npc','x','data:image/webp;base64,AAAA',1,1)$$, 'visitante não envia imagem', 'permission denied');
select t.fails($$select * from public.media$$, 'tabela media fechada para a API', 'permission denied');
select member_id as ma, member_token as ta from public.join_table_by_code('SV-F2AA','Ana') \gset
reset role;
update public.tables set session_state = jsonb_build_object(
  'npcs', jsonb_build_array(
    jsonb_build_object('id','n1','name','Madame Rubra','desc','Leiloeira','notes','SEGREDO','reveal',3,'imageId',:'m1','imageFit','contain'),
    jsonb_build_object('id','n2','name','Vulto','reveal',1,'imageId',:'m2'),
    jsonb_build_object('id','n3','name','Alheio','reveal',4,'imageId',:'mx')),
  'activeNpcId','n1',
  'scenes', jsonb_build_array(jsonb_build_object('id','s1','title','Salão','shared',true,'imageId',:'m3')),
  'activeSceneId','s1') where id = :'tid';
set role anon;
select public.player_get_session(:'ma', :'ta') as st \gset
select t.ok((:'st'::jsonb->'dialogue'->>'name') = 'Madame Rubra' and (:'st'::jsonb->'dialogue'->>'desc') = 'Leiloeira', 'diálogo chega com nome e descrição públicos');
select t.ok(:'st' not like '%SEGREDO%', 'notas do NPC não chegam');
select t.ok(not ((:'st'::jsonb->'dialogue') ? 'imageId') and :'st' not like '%' || :'m1' || '%', 'retrato ainda não revelado (nível 3): sem imagem nem id');
select t.ok(:'st' not like '%' || :'m2' || '%', 'NPC oculto: nem o id da imagem chega');
select t.ok(public.player_media(:'ma', :'ta', array[:'m1'::uuid, :'m2'::uuid]) = '{}'::jsonb, 'imagem de NPC não revelado não é entregue');
select t.ok((public.player_media(:'ma', :'ta', array[:'m3'::uuid])->>:'m3') like 'data:image/jpeg%', 'imagem da cena ativa compartilhada é entregue');
select t.ok(public.player_media(:'ma', :'ta', array[:'mx'::uuid]) = '{}'::jsonb, 'imagem de outra conta não é entregue, mesmo referenciada');
reset role; update public.tables set session_state = jsonb_set(session_state, '{npcs,0,reveal}', '4') where id = :'tid'; set role anon;
select public.player_get_session(:'ma', :'ta') as st2 \gset
select t.ok((:'st2'::jsonb->'dialogue'->>'imageId') = :'m1' and (:'st2'::jsonb->'dialogue'->>'imageFit') = 'contain', 'retrato revelado (nível 4): diálogo traz a imagem');
select t.ok((public.player_media(:'ma', :'ta', array[:'m1'::uuid])->>:'m1') like 'data:image/webp%', 'retrato revelado é entregue');
select t.fails(format($$select public.player_media(%L,'x',array[%L::uuid])$$, :'ma', :'m1'), 'sem vínculo válido não lê imagem', 'not_authorized');
reset role; update public.tables set session_state = session_state - 'activeNpcId' where id = :'tid'; set role anon;
select t.ok((public.player_get_session(:'ma', :'ta')->'dialogue') = 'null'::jsonb, 'encerrar diálogo: nada chega');
do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
