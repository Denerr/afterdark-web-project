-- Testes SQL da Etapa 0 pós-sessão (migration_identity.sql): entrada repetível,
-- vínculo de visitante à conta, aba Mesas e correção de duplicatas.
-- Rodar numa base limpa com todas as migrações (ver run_all.sh).
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
create function t.v(k text) returns text language sql stable as $$ select current_setting('t.'||k) $$;
grant execute on function t.v(text) to anon, authenticated;
create function t.cnt(tid uuid) returns int language sql security definer as $$ select count(*)::int from public.table_members where table_id = tid $$;
grant execute on function t.cnt(uuid) to anon, authenticated;

-- M = mestre, L = jogador com conta, X = outra conta
insert into auth.users(id) values
 ('11111111-1111-1111-1111-111111111111'),('22222222-2222-2222-2222-222222222222'),('33333333-3333-3333-3333-333333333333');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa E0','SV-E0AA') returning id as tid \gset
insert into public.tables(name, invite_code) values ('Mesa E0b','SV-E0BB') returning id as tid2 \gset
insert into public.tables(name, invite_code) values ('Mesa E0c','SV-E0CC');
select set_config('t.tid', :'tid', false), set_config('t.tid2', :'tid2', false);

-- Dono não entra como jogador na própria mesa
select t.fails($$select * from public.join_table_by_code('SV-E0AA','Mestre')$$, 'dono não entra como jogador na própria mesa', 'owner_cannot_join');

-- ---- visitante: credencial do navegador reaproveita o membro ----
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as va, member_token as vta, reused as r0 from public.join_table_by_code('SV-E0AA','Ana') \gset
select set_config('t.va', :'va', false), set_config('t.vta', :'vta', false);
select t.ok(not :'r0'::boolean, 'primeira entrada cria membro (reused=false)');
select member_id as va2, reused as r1, member_token as vta2 from public.join_table_by_code('SV-E0AA','Ana',
  jsonb_build_array(jsonb_build_object('member_id', :'va', 'token', :'vta'))) \gset
select t.ok(:'va2' = :'va' and :'r1'::boolean, 'reentrada com a credencial devolve o MESMO membro');
select t.ok(:'vta2' = :'vta', 'reentrada devolve o mesmo token (não gira o segredo)');
select t.ok(t.cnt(:'tid') = 1, 'reentrada não cria segundo participante');
-- cinco reentradas seguidas (F5, link reaberto, pausa/retomada)
select count(distinct j.member_id) = 1 as one from generate_series(1,5) g,
  lateral public.join_table_by_code('SV-E0AA','Ana', jsonb_build_array(jsonb_build_object('member_id', t.v('va'), 'token', t.v('vta')))) j \gset
select t.ok(:'one'::boolean and t.cnt(t.v('tid')::uuid) = 1, 'cinco reentradas: mesmo id, um participante');
-- token errado não reaproveita (cria um novo, não assume o de outro)
select member_id as vx from public.join_table_by_code('SV-E0AA','Intruso',
  jsonb_build_array(jsonb_build_object('member_id', :'va', 'token', repeat('0',64)))) \gset
select t.ok(:'vx' <> :'va', 'token inválido não assume a ficha de outro');
-- credencial de outra mesa não serve para esta
select member_id as vb, member_token as vtb from public.join_table_by_code('SV-E0BB','Bia') \gset
select member_id as vb2 from public.join_table_by_code('SV-E0AA','Bia',
  jsonb_build_array(jsonb_build_object('member_id', :'vb', 'token', :'vtb'))) \gset
select t.ok(:'vb2' <> :'vb', 'credencial de outra mesa não é reaproveitada');
-- lixo em p_creds não quebra a entrada
select t.ok((select member_id is not null from public.join_table_by_code('SV-E0BB','Z', '[{"member_id":"nao-uuid"},{"x":1},null]'::jsonb)), 'p_creds malformado é ignorado');
-- mesmo nome = pessoas diferentes
reset role; select set_config('t.n_before', (select count(*)::text from public.table_members where table_id=:'tid'), false);
set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ana2 from public.join_table_by_code('SV-E0AA','Ana') \gset
select t.ok(:'ana2' <> :'va' and t.cnt(:'tid') = t.v('n_before')::int + 1, 'dois visitantes com o mesmo nome continuam separados');

-- ---- conta: entrada repetível ----
reset role; set role authenticated; select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
select member_id as la, member_token as lt from public.join_table_by_code('SV-E0BB','Leo') \gset
select set_config('t.la', :'la', false);
select member_id as la2, reused as lr from public.join_table_by_code('SV-E0BB','Leo') \gset
select t.ok(:'la2' = :'la' and :'lr'::boolean, 'conta reentra na mesma participação, sem credencial do navegador');
select t.ok((select member_token is null from public.join_table_by_code('SV-E0BB','Leo')), 'reentrada pela conta não expõe token (auth.uid() autoriza)');
select t.ok((public.player_get_state(:'la', null)->'member'->>'id') = :'la', 'conta lê o próprio estado depois de reentrar');

-- ---- visitante que faz login durante a entrada: vínculo com as duas provas ----
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as vc, member_token as vtc from public.join_table_by_code('SV-E0AA','Caio') \gset
select set_config('t.vc', :'vc', false), set_config('t.vtc', :'vtc', false);
reset role; select set_config('afterdark.trusted','on',false);
update public.table_members set char_name='Corvo', char_data='{"name":"Corvo","weaknesses":["prata"]}', sheet_ready=true, approved_at=now(),
  wounds='[{"id":"w1","lvl":1}]', conditions='["Abalado"]' where id=:'vc';
insert into public.table_requests(table_id,target_member_id,created_by,client_key,kind) values (:'tid',:'vc','11111111-1111-1111-1111-111111111111',gen_random_uuid(),'geral');
select set_config('afterdark.trusted','',false);
set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select member_id as vc2, linked as lk, char_name as ch from public.join_table_by_code('SV-E0AA','Caio',
  jsonb_build_array(jsonb_build_object('member_id', :'vc', 'token', :'vtc'))) \gset
select t.ok(:'vc2' = :'vc' and :'lk'::boolean and :'ch' = 'Corvo', 'login durante a entrada: mesmo membro, vinculado à conta');
reset role;
select t.ok((select user_id='33333333-3333-3333-3333-333333333333' and approved_at is not null and sheet_ready
  and wounds<>'[]'::jsonb and conditions<>'[]'::jsonb and char_data->'weaknesses' ? 'prata' from public.table_members where id=:'vc'),
  'ficha, aprovação e consequências preservadas no vínculo');
select t.ok((select count(*)=1 from public.table_requests where target_member_id=:'vc'), 'solicitação continua destinada ao mesmo membro');
-- depois do vínculo, a conta reentra sem credencial
set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.ok((select member_id from public.join_table_by_code('SV-E0AA','Caio'))::text = t.v('vc'), 'conta vinculada reentra no mesmo membro (outro dispositivo)');
-- outra conta usando a credencial de Caio (computador compartilhado) não assume a ficha
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
select member_id as lc from public.join_table_by_code('SV-E0AA','Leo',
  jsonb_build_array(jsonb_build_object('member_id', t.v('vc'), 'token', t.v('vtc')))) \gset
select t.ok(:'lc' <> t.v('vc'), 'credencial de outra conta é ignorada (não troca o dono da ficha)');
reset role; select t.ok((select user_id='33333333-3333-3333-3333-333333333333' from public.table_members where id=t.v('vc')::uuid), 'ficha de Caio continua da conta de Caio');

-- ---- conflito: conta já tem ficha e chega com credencial de visitante ----
set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as vd, member_token as vtd from public.join_table_by_code('SV-E0BB','Leo visitante') \gset
set role authenticated; select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
select member_id as cm, conflict_member_id as cf, linked as clk from public.join_table_by_code('SV-E0BB','Leo',
  jsonb_build_array(jsonb_build_object('member_id', :'vd', 'token', :'vtd'))) \gset
select t.ok(:'cm' = t.v('la') and :'cf' = :'vd' and not :'clk'::boolean, 'conflito devolve as duas participações e não funde');
reset role; select t.ok((select user_id is null from public.table_members where id=:'vd'), 'participação de visitante em conflito continua separada');
set role authenticated; select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
select t.ok((public.player_link_account(:'vd', :'vtd')->>'conflict')::boolean, 'vincular com conflito explícito é recusado');

-- ---- player_link_account ----
set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ve, member_token as vte from public.join_table_by_code('SV-E0CC','Eva') \gset
select t.fails(format($$select public.player_link_account(%L,%L)$$, :'ve', :'vte'), 'visitante sem conta não vincula', 'permission denied|not_authenticated');
set role authenticated; select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
select t.fails(format($$select public.player_link_account(%L,%L)$$, :'ve', repeat('1',64)), 'token errado não vincula', 'not_authorized');
select t.fails(format($$select public.player_link_account(%L,null)$$, :'ve'), 'sem token não vincula', 'not_authorized');
select t.ok((public.player_link_account(:'ve', :'vte')->>'linked')::boolean, 'conta + token vinculam o visitante');
select t.ok((public.player_link_account(:'ve', :'vte')->>'already')::boolean, 'vincular de novo é idempotente');
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.fails(format($$select public.player_link_account(%L,%L)$$, :'ve', :'vte'), 'participação de outra conta não é tomada', 'member_other_account');
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as vf, member_token as vtf from public.join_table_by_code('SV-E0AA','Fê') \gset
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.fails(format($$select public.player_link_account(%L,%L)$$, :'vf', :'vtf'), 'dono não vira jogador da própria mesa por vínculo', 'owner_cannot_join');

-- ---- aba Mesas ----
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
select t.ok((select count(*) from jsonb_array_elements(public.my_memberships()) e)=3, 'conta lista suas participações (2 mesas + vinculada)');
select t.ok(public.my_memberships()::text like '%Mesa E0b%' and public.my_memberships()::text not like '%Corvo%', 'lista só as participações da própria conta');
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.ok(jsonb_array_length(public.my_memberships())=0, 'mesas mestradas não aparecem como jogador');
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.fails($$select public.my_memberships()$$, 'visitante não chama my_memberships', 'permission denied');
select public.player_check_memberships(jsonb_build_array(
  jsonb_build_object('member_id', t.v('va'), 'token', t.v('vta')),
  jsonb_build_object('member_id', t.v('vc'), 'token', 'x'),
  jsonb_build_object('member_id', t.v('vc'), 'token', repeat('9',64)))) as chk \gset
select t.ok((:'chk'::jsonb->0->>'valid')::boolean and (:'chk'::jsonb->0->>'table_name')='Mesa E0', 'credencial válida lista a mesa do visitante');
select t.ok(not (:'chk'::jsonb->1->>'valid')::boolean and not (:'chk'::jsonb->2->>'valid')::boolean and :'chk' not like '%Corvo%', 'credencial inválida não revela a mesa');
-- participação removida pelo mestre: indisponível e não volta pela API
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
delete from public.table_members where id = t.v('va')::uuid;
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.ok(not (public.player_check_memberships(jsonb_build_array(jsonb_build_object('member_id', t.v('va'), 'token', t.v('vta'))))->0->>'valid')::boolean, 'participação removida aparece como indisponível');
select t.fails(format($$select public.player_get_state(%L,%L)$$, t.v('va'), t.v('vta')), 'participação removida não é reativada por chamada direta', 'not_authorized');
select member_id as va3 from public.join_table_by_code('SV-E0AA','Ana', jsonb_build_array(jsonb_build_object('member_id', t.v('va'), 'token', t.v('vta')))) \gset
select t.ok(:'va3' <> t.v('va'), 'credencial removida não ressuscita o membro antigo (convite cria um novo, sem ficha)');
reset role; select t.ok((select char_name is null and approved_at is null from public.table_members where id=:'va3'), 'nova entrada após remoção começa sem ficha e sem aprovação');

-- ---- índice de unicidade e correção de duplicatas ----
select set_config('afterdark.trusted','on',false);
select t.ok(exists(select 1 from pg_indexes where indexname='table_members_one_per_account'), 'índice de unicidade criado (base sem duplicatas)');
select t.fails($$insert into public.table_members(table_id,user_id,player_name) select table_id,user_id,'dup' from public.table_members where user_id is not null limit 1$$,
  'banco recusa segunda participação da mesma conta', 'duplicate key|unique');
-- simula a base de produção: derruba o índice e cria uma duplicata
drop index public.table_members_one_per_account;
insert into public.table_members(table_id,user_id,player_name,char_name) values (t.v('tid2')::uuid,'22222222-2222-2222-2222-222222222222','Leo','Dup') returning id as dup \gset
update public.tables set session_state = jsonb_build_object('stressBars', jsonb_build_array(jsonb_build_object('member', :'dup', 'v', 2))) where id = t.v('tid2')::uuid;
insert into public.table_requests(table_id,target_member_id,created_by,client_key,kind) values (t.v('tid2')::uuid,:'dup','11111111-1111-1111-1111-111111111111',gen_random_uuid(),'geral');
select set_config('afterdark.trusted','',false);
\i /tmp/mig.sql
select t.ok(not exists(select 1 from pg_indexes where indexname='table_members_one_per_account'), 'com duplicata, a migração avisa e não cria o índice');
select t.fails(format($$select public._ad_merge_member(%L,%L)$$, t.v('la'), :'vd'), 'merge recusa visitante/conta diferente', 'mesma conta');
select t.fails(format($$select public._ad_merge_member(%L,%L)$$, t.v('la'), t.v('vc')), 'merge recusa mesas diferentes', 'mesas diferentes');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.fails(format($$select public._ad_merge_member(%L,%L)$$, t.v('la'), :'dup'), 'merge fechado para a API', 'permission denied');
reset role;
select public._ad_merge_member(t.v('la')::uuid, :'dup');
select t.ok(not exists(select 1 from public.table_members where id=:'dup'), 'duplicata removida');
select t.ok((select count(*)=1 from public._ad_members_archive where member_id=:'dup' and row_data->>'char_name'='Dup'), 'duplicata arquivada para recuperação');
select t.ok((select count(*)=1 from public.table_requests where target_member_id=t.v('la')::uuid), 'solicitações migradas para o membro que fica');
select t.ok((select session_state::text like '%'||t.v('la')||'%' and session_state::text not like '%'||:'dup'||'%' from public.tables where id=t.v('tid2')::uuid), 'referências no estado da sessão migradas');
\i /tmp/mig.sql
select t.ok(exists(select 1 from pg_indexes where indexname='table_members_one_per_account'), 'rodar a migração de novo cria o índice');
select t.ok(not has_table_privilege('anon','public._ad_members_archive','select') and not has_table_privilege('authenticated','public._ad_members_archive','select'), 'arquivo fechado para a API');

do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
