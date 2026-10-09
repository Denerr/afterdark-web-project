-- Testes SQL da Etapa 5 do plano final (migration_final_map_marks.sql): marcações no mapa.
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
create function t.q(sql text) returns text language plpgsql security definer as $$ declare r text; begin execute sql into r; return r; end $$;
grant execute on function t.q(text) to anon, authenticated;
insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111'),('33333333-3333-3333-3333-333333333333');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code, status, session_state) values ('Mesa F5','SV-F5AA','Em andamento','{"activeMapId":"m1"}') returning id as tid \gset
insert into public.tables(name, invite_code, status, session_state) values ('Outra','SV-F5BB','Em andamento','{"activeMapId":"m1"}') returning id as tid2 \gset
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as ta from public.join_table_by_code('SV-F5AA','Ana') \gset
select member_id as mb, member_token as tb from public.join_table_by_code('SV-F5AA','Bia') \gset
select member_id as mc, member_token as tc from public.join_table_by_code('SV-F5BB','Caio') \gset
reset role; select set_config('afterdark.trusted','on',false);
update public.table_members set char_name = case when id=:'ma' then 'Corvo' else 'Lis' end where id in (:'ma',:'mb');
select set_config('afterdark.trusted','',false);
set role anon;

-- jogador
select public.player_mark_move(:'ma', :'ta', 'm1', 0.25, 0.5) as r1 \gset
select t.ok((:'r1'::jsonb->'mark'->>'label') = 'Corvo' and (:'r1'::jsonb->'mark'->>'x')::real = 0.25, 'jogador posiciona o próprio marcador (coordenada relativa)');
select public.player_mark_move(:'ma', :'ta', 'm1', 0.30, 0.55) as r2 \gset
select t.ok((:'r2'::jsonb->'mark'->>'id') = (:'r1'::jsonb->'mark'->>'id') and (:'r2'::jsonb->'mark'->>'rev')::int = 2, 'mover de novo atualiza o mesmo marcador (um por participante e mapa)');
select public.player_mark_move(:'mb', :'tb', 'm1', 0.7, 0.2);
reset role;
select t.ok((select count(*) from public.map_marks where table_id = :'tid' and kind = 'pc') = 2 and (select x from public.map_marks where member_id = :'ma') = 0.30::real, 'dois jogadores movendo: as duas posições preservadas');
set role anon;
select t.fails(format($$select public.player_mark_move(%L,%L,'m2',0.1,0.1)$$, :'ma', :'ta'), 'só no mapa ativo', 'map_not_active');
select t.fails(format($$select public.player_mark_move(%L,%L,'m1',1.5,0.1)$$, :'ma', :'ta'), 'coordenada fora de 0..1 recusada', 'invalid_request');
select t.fails(format($$select public.player_mark_move(%L,%L,'m1',0.1,0.1)$$, :'mb', :'ta'), 'jogador não move o marcador de outro', 'not_authorized');
select t.fails($$select public.master_mark_upsert('00000000-0000-0000-0000-000000000000','{}')$$, 'jogador não usa as funções do Mestre', 'permission denied');
select t.fails($$select * from public.map_marks$$, 'tabela fechada para a API', 'permission denied');

-- Mestre
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select public.master_mark_upsert(:'tid', '{"id":"aaaaaaaa-5555-0000-0000-000000000001","mapId":"m1","kind":"point","label":"Porta","descr":"Trancada","icon":"porta","x":0.5,"y":0.5,"visibility":"public"}');
select public.master_mark_upsert(:'tid', '{"id":"aaaaaaaa-5555-0000-0000-000000000001","mapId":"m1","kind":"point","label":"Porta","descr":"Trancada","icon":"porta","x":0.5,"y":0.5,"visibility":"public"}');
select t.ok(t.q($q$select count(*) from public.map_marks where id = 'aaaaaaaa-5555-0000-0000-000000000001'$q$)::int = 1, 'repetir a mesma operação do Mestre não duplica');
select public.master_mark_upsert(:'tid', '{"id":"aaaaaaaa-5555-0000-0000-000000000002","mapId":"m1","kind":"npc","npcId":"n1","label":"Madame Rubra","x":0.6,"y":0.4,"visibility":"private"}');
select public.master_mark_upsert(:'tid', '{"id":"aaaaaaaa-5555-0000-0000-000000000003","mapId":"m1","kind":"route","label":"Fuga","points":[[0.1,0.1],[0.5,0.2],[0.9,0.9]],"visibility":"public"}');
select t.fails(format($$select public.master_mark_upsert(%L,'{"id":"aaaaaaaa-5555-0000-0000-000000000004","mapId":"m1","kind":"route","points":[[0.1,0.1]]}')$$, :'tid'), 'rota precisa de 2+ pontos', 'invalid_request');
select public.master_mark_upsert(:'tid', jsonb_build_object('id','aaaaaaaa-5555-0000-0000-000000000099','mapId','m1','kind','pc','memberId',:'mb','x',0.11,'y',0.22));
select t.ok(t.q(format($q$select count(*) from public.map_marks where member_id = %L$q$, :'mb'))::int = 1 and t.q(format($q$select x from public.map_marks where member_id = %L$q$, :'mb'))::real = 0.11::real, 'Mestre reposiciona o marcador do jogador (sem duplicar)');
select t.ok(jsonb_array_length(public.master_marks(:'tid')) = 5, 'Mestre lê todas as marcações (inclusive privadas)');
-- jogador vê públicas e pcs, não a privada
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select public.player_get_session(:'ma', :'ta') as st \gset
select t.ok(jsonb_array_length(:'st'::jsonb->'marks') = 4 and :'st' like '%Porta%' and :'st' like '%Fuga%' and :'st' not like '%Madame Rubra%', 'jogador recebe públicas e marcadores de personagem; privada não sai');
select t.ok(public.player_get_session(:'mc', :'tc')::text not like '%Porta%', 'outra mesa não vê as marcações desta');
-- pausa
reset role; update public.tables set status='Pausada · retomar depois' where id = :'tid'; set role anon;
select t.fails(format($$select public.player_mark_move(%L,%L,'m1',0.2,0.2)$$, :'ma', :'ta'), 'pausa bloqueia mover marcador', 'table_paused');
reset role; update public.tables set status='Em andamento' where id = :'tid';
-- outra conta / limpar / remover participante
set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.fails(format($$select public.master_mark_clear(%L,'m1')$$, :'tid'), 'outra conta não limpa o mapa', 'not_authorized');
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select public.master_mark_delete(:'tid', 'aaaaaaaa-5555-0000-0000-000000000003');
select t.ok(t.q($q$select count(*) from public.map_marks where id = 'aaaaaaaa-5555-0000-0000-000000000003'$q$)::int = 0, 'Mestre remove uma marcação');
delete from public.table_members where id = :'mb';
select t.ok(t.q(format($q$select count(*) from public.map_marks where member_id = %L$q$, :'mb'))::int = 0, 'participante removido: marcador dele some junto');
reset role; set role anon;
select t.fails(format($$select public.player_mark_move(%L,%L,'m1',0.2,0.2)$$, :'mb', :'tb'), 'participante removido perde a escrita', 'not_authorized');
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.ok((public.master_mark_clear(:'tid','m1')->>'removed')::int = 3 and t.q(format($q$select count(*) from public.table_members where table_id = %L$q$, :'tid'))::int = 1, 'limpar o mapa remove as marcações, sem apagar participantes');
do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
