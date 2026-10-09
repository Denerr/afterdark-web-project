-- Testes SQL da Etapa 1 do plano final (migration_final_pause.sql): pausa bloqueia as
-- ações do jogador na mesa; o Mestre e o lobby não são afetados.
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
insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code, session_state) values ('Mesa F1','SV-F1AA','{"library":{"items":[{"id":"i1","name":"Lanterna"}],"weapons":[]}}') returning id as tid \gset
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as ta from public.join_table_by_code('SV-F1AA','Ana') \gset
reset role; select set_config('afterdark.trusted','on',false);
update public.table_members set char_name='Corvo' where id=:'ma';
insert into public.table_requests(id,table_id,target_member_id,created_by,client_key,kind) values
 ('aaaaaaaa-1111-0000-0000-000000000001',:'tid',:'ma','11111111-1111-1111-1111-111111111111',gen_random_uuid(),'geral'),
 ('aaaaaaaa-1111-0000-0000-000000000002',:'tid',:'ma','11111111-1111-1111-1111-111111111111',gen_random_uuid(),'geral');
select set_config('afterdark.trusted','',false);
set role anon;
-- lobby liberado
select t.ok((public.member_equip(:'ma',:'ta','add','items','i1','iid-lobby-01')->>'ok')::boolean, 'lobby: jogador pega item');
select t.ok((public.player_answer_request(:'ma',:'ta','aaaaaaaa-1111-0000-0000-000000000001','{"grade":"x"}')->>'ok')::boolean, 'lobby: jogador responde teste');
-- pausa
reset role; update public.tables set status='Pausada · retomar depois' where id=:'tid'; set role anon;
select t.fails(format($$select public.member_equip(%L,%L,'add','items','i1','iid-pausa-01')$$, :'ma', :'ta'), 'pausa: jogador não pega item', 'table_paused');
select t.fails(format($$select public.member_equip(%L,%L,'remove','items','i1','iid-lobby-01')$$, :'ma', :'ta'), 'pausa: jogador não larga item', 'table_paused');
select t.fails(format($$select public.player_answer_request(%L,%L,'aaaaaaaa-1111-0000-0000-000000000002','{"grade":"x"}')$$, :'ma', :'ta'), 'pausa: jogador não responde teste pendente', 'table_paused');
select t.ok((public.player_answer_request(:'ma',:'ta','aaaaaaaa-1111-0000-0000-000000000001','{"grade":"x"}')->>'duplicate')::boolean, 'pausa: reenvio de resposta já gravada continua idempotente');
select t.ok((public.member_set_photo(:'ma',:'ta','data:image/jpeg;base64,/9j/AAAA')->>'ok')::boolean, 'pausa: foto continua livre');
select t.ok((public.player_get_state(:'ma',:'ta')->'member'->>'id') = :'ma', 'pausa: ficha continua legível');
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.ok((public.member_equip(:'ma',null,'add','items','i1','iid-mestre-01')->>'ok')::boolean, 'pausa: o Mestre continua ajustando');
-- encerrada também bloqueia; retomada libera
reset role; update public.tables set status='Encerrada' where id=:'tid'; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.fails(format($$select public.member_equip(%L,%L,'add','items','i1','iid-fim-01')$$, :'ma', :'ta'), 'encerrada: jogador não pega item', 'table_paused');
reset role; update public.tables set status='Em andamento' where id=:'tid'; set role anon;
select t.ok((public.member_equip(:'ma',:'ta','add','items','i1','iid-volta-01')->>'ok')::boolean and (public.player_answer_request(:'ma',:'ta','aaaaaaaa-1111-0000-0000-000000000002','{"grade":"x"}')->>'ok')::boolean, 'retomada: ações voltam');
do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
