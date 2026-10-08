-- Testes SQL da Etapa 1 pós-sessão (migration_equipment_photo.sql): equipamento por
-- personagem (catálogo -> exemplares) e foto na mesa.
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

insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111'),('33333333-3333-3333-3333-333333333333');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code, session_state) values ('Mesa E1','SV-E1AA',
  '{"library":{"weapons":[{"id":"w1","name":"Pistola","bonus":1,"dano":2,"alcance":"Médio","ruido":"Alto"}],"items":[{"id":"i1","name":"Lanterna","desc":"Ilumina"}]}}')
  returning id as tid \gset
insert into public.tables(name, invite_code) values ('Outra','SV-E1BB') returning id as tid2 \gset
select set_config('t.tid', :'tid', false);
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as ta from public.join_table_by_code('SV-E1AA','Ana') \gset
select member_id as mb, member_token as tb from public.join_table_by_code('SV-E1AA','Bia') \gset
select member_id as mc, member_token as tc from public.join_table_by_code('SV-E1BB','Caio') \gset
select set_config('t.ma', :'ma', false), set_config('t.ta', :'ta', false), set_config('t.mb', :'mb', false), set_config('t.tb', :'tb', false);

-- ---- equipamento: jogador pega do catálogo ----
select public.member_equip(:'ma', :'ta', 'add', 'weapons', 'w1', 'iid-pistola-1') as r \gset
select t.ok((:'r'::jsonb->>'rev')::int = 1 and jsonb_array_length(:'r'::jsonb->'equipment') = 1, 'jogador pega arma do catálogo (rev 1)');
select t.ok((:'r'::jsonb->'equipment'->0->>'name') = 'Pistola' and (:'r'::jsonb->'equipment'->0->>'bonus')::int = 1 and (:'r'::jsonb->'equipment'->0->>'by') = 'jogador', 'exemplar guarda os dados do item e quem pegou');
select public.member_equip(:'ma', :'ta', 'add', 'weapons', 'w1', 'iid-pistola-1') as r2 \gset
select t.ok((:'r2'::jsonb->>'dup')::boolean and (:'r2'::jsonb->>'rev')::int = 1, 'repetir a mesma operação (mesmo iid) não duplica');
select public.member_equip(:'ma', :'ta', 'add', 'weapons', 'w1', 'iid-pistola-2') as r3 \gset
select t.ok(jsonb_array_length(:'r3'::jsonb->'equipment') = 2, 'catálogo: o mesmo item pode virar dois exemplares distintos');
select public.member_equip(:'ma', :'ta', 'add', 'items', 'i1', 'iid-lanterna-1') as r4 \gset
select t.ok((:'r4'::jsonb->>'rev')::int = 3, 'item entra e a revisão cresce a cada mudança');
select t.fails(format($$select public.member_equip(%L,%L,'add','weapons','w-inventada','iid-x-00001')$$, :'ma', :'ta'), 'jogador não cria item fora do catálogo do Mestre', 'not_in_catalog');
select t.fails(format($$select public.member_equip(%L,%L,'add','pocao','i1','iid-x-00002')$$, :'ma', :'ta'), 'tipo inválido recusado', 'invalid_request');
select t.fails(format($$select public.member_equip(%L,%L,'add','items','i1','x')$$, :'ma', :'ta'), 'iid inválido recusado', 'invalid_request');
-- terceiros
select t.fails(format($$select public.member_equip(%L,%L,'add','items','i1','iid-x-00003')$$, :'mb', :'ta'), 'jogador não mexe no equipamento de outro (token alheio)', 'not_authorized');
select t.fails(format($$select public.member_equip(%L,null,'remove','weapons','w1','iid-pistola-1')$$, :'ma'), 'sem token não mexe', 'not_authorized');
-- largar
select public.member_equip(:'ma', :'ta', 'remove', 'weapons', 'w1', 'iid-pistola-2') as r5 \gset
select t.ok(jsonb_array_length(:'r5'::jsonb->'equipment') = 2 and :'r5' like '%iid-pistola-1%' and :'r5' not like '%iid-pistola-2%', 'largar remove só aquele exemplar');
select public.member_equip(:'ma', :'ta', 'remove', 'weapons', 'w1', 'iid-pistola-2') as r6 \gset
select t.ok((:'r6'::jsonb->>'dup')::boolean, 'largar de novo é no-op (não falha, não muda)');
-- leitura do próprio estado
select t.ok((public.player_get_state(:'ma', :'ta')->'member'->>'equip_rev')::int = 4
  and jsonb_array_length(public.player_get_state(:'ma', :'ta')->'member'->'equipment') = 2, 'player_get_state devolve o equipamento confirmado e a revisão');
select t.ok(public.player_get_lobby(:'mb', :'tb')::text not like '%iid-pistola%', 'colegas não recebem o equipamento dos outros pelo lobby');

-- ---- Mestre ----
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select public.member_equip(t.v('mb')::uuid, null, 'add', 'items', 'i1', 'iid-mestre-1') as rm \gset
select t.ok((:'rm'::jsonb->'equipment'->0->>'by') = 'mestre', 'Mestre atribui item ao personagem');
select t.ok((select equipment::text like '%iid-mestre-1%' from public.table_members where id=t.v('mb')::uuid), 'Mestre lê a posse direto (dono da mesa)');
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.fails(format($$select public.member_equip(%L,null,'add','items','i1','iid-x-00004')$$, t.v('mb')), 'outra conta não atribui', 'not_authorized');
-- catálogo muda depois: o exemplar mantém a identidade e os dados
reset role;
update public.tables set session_state = jsonb_set(session_state, '{library,weapons}', '[{"id":"w1","name":"Pistola nova","bonus":3}]') where id = t.v('tid')::uuid;
select t.ok((select equipment->0->>'name' = 'Pistola' from public.table_members where id = t.v('ma')::uuid), 'mudar o catálogo não altera o exemplar já atribuído');
-- acesso direto continua fechado
set role anon; select set_config('request.jwt.claim.sub','',false);
select t.fails(format($$update public.table_members set equipment='[]' where id=%L$$, t.v('ma')), 'anon não grava equipamento direto', 'permission denied');

-- ---- foto ----
select public.member_set_photo(:'ma', :'ta', 'data:image/jpeg;base64,/9j/AAAA') as p1 \gset
select t.ok((:'p1'::jsonb->>'rev')::int = 1, 'jogador define a foto (rev 1)');
select t.fails(format($$select public.member_set_photo(%L,%L,'https://exemplo.com/x.png')$$, :'ma', :'ta'), 'URL externa recusada', 'photo_invalid');
select t.fails(format($$select public.member_set_photo(%L,%L,'data:image/svg+xml;base64,PHN2Zz4=')$$, :'ma', :'ta'), 'SVG recusado', 'photo_invalid');
select t.fails(format($$select public.member_set_photo(%L,%L,'data:image/png;base64,'||repeat('A',200001))$$, :'ma', :'ta'), 'foto grande demais recusada', 'photo_too_large');
select t.ok((public.member_photos(:'ma', :'ta')->t.v('ma')->>'photo') = 'data:image/jpeg;base64,/9j/AAAA', 'falha de envio mantém a foto anterior');
select t.fails(format($$select public.member_set_photo(%L,%L,'data:image/png;base64,AAAA')$$, :'mb', :'ta'), 'jogador não troca a foto de outro', 'not_authorized');
select public.member_set_photo(:'mb', :'tb', 'data:image/png;base64,BBBB');
select t.ok((public.member_photos(:'ma', :'ta')->t.v('ma')->>'photo') like '%AAAA' and (public.member_photos(:'ma', :'ta')->t.v('mb')->>'photo') like '%BBBB', 'fotos de dois personagens não se sobrescrevem');
select t.ok((select count(*) from jsonb_object_keys(public.member_photos(:'ma', :'ta', array[t.v('mb')::uuid])))=1, 'member_photos filtra pelos ids pedidos');
select t.fails(format($$select public.member_photos(%L,%L)$$, :'mc', 'x'), 'sem vínculo válido não lê fotos', 'not_authorized');
select t.ok(public.member_photos(:'mc', :'tc')::text not like '%AAAA%', 'participante de outra mesa não vê fotos desta');
select t.ok((public.player_get_lobby(:'mb', :'tb')->'members'->0->>'photo_rev')::int = 1 and public.player_get_lobby(:'mb', :'tb')::text not like '%AAAA%', 'lobby traz só a revisão da foto, não a imagem');
select public.member_set_photo(:'ma', :'ta', null) as p2 \gset
select t.ok((:'p2'::jsonb->>'rev')::int = 2 and (public.member_photos(:'ma', :'ta')->t.v('ma')->>'photo') is null, 'remover a foto é persistido (rev 2)');
select t.ok(jsonb_array_length(public.player_get_state(:'ma', :'ta')->'member'->'equipment') = 2, 'remover foto não mexe no resto da ficha (equipamento intacto)');
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.ok((public.member_set_photo(t.v('mb')::uuid, null, 'data:image/webp;base64,CCCC')->>'rev')::int = 2, 'Mestre também pode definir a foto');
select t.ok(public.member_photos(t.v('ma')::uuid, null)::text like '%CCCC%', 'Mestre lê as fotos da mesa');
select t.ok(not has_function_privilege('anon','public._ad_member_actor(uuid,text)','execute'), 'helper _ad_member_actor fechado');

do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
