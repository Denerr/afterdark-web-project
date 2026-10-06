-- Testes SQL do Ponto 3: versão por mesa, notas privadas, status e biblioteca por conta.
-- Rodar numa base limpa, com as 12 migrações na ordem do INSTALL.md.
-- Esperado: todas as linhas PASSOU e 'TODOS OS TESTES DO PONTO 3 PASSARAM'.
\set ON_ERROR_STOP 1

create schema t;
grant usage on schema t to anon, authenticated;
create function t.ok(c boolean, msg text) returns void language plpgsql as $fn$
begin if c is not true then raise exception 'FALHOU: %', msg; end if; raise notice 'PASSOU: %', msg; end $fn$;
create function t.fails(q text, msg text, pat text default null) returns void language plpgsql as $fn$
begin
  begin execute q; exception when others then
    if pat is not null and sqlerrm !~ pat then raise exception 'FALHOU (erro inesperado "%"): %', sqlerrm, msg; end if;
    raise notice 'PASSOU (bloqueado: %): %', sqlerrm, msg; return;
  end;
  raise exception 'FALHOU (deveria bloquear): %', msg;
end $fn$;
grant execute on all functions in schema t to anon, authenticated;
create function t.v(k text) returns text language sql stable as $fn$ select current_setting('t.'||k) $fn$;
grant execute on function t.v(text) to anon, authenticated;

-- M = mestre, X = outro usuário logado
insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111'),('33333333-3333-3333-3333-333333333333');

set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa P3','SV-P301') returning id as ta \gset
insert into public.tables(name, invite_code) values ('Mesa P3 B','SV-P302') returning id as tb \gset
select set_config('t.ta',:'ta',false), set_config('t.tb',:'tb',false);

-- Leitura inicial: versão 0, estado e notas vazios
select t.ok((public.master_get_session(:'ta')->>'version')::bigint = 0, 'mesa nova começa na versão 0');

-- Gravação com a versão certa avança a versão e grava estado + notas
select t.ok((public.master_save_session(:'ta', '{"clocks":[{"id":"c1"}]}', '{"roteiro":{"text":"segredo do mestre"}}', 0)->>'version')::bigint = 1,
  'gravação na versão base 0 devolve versão 1');
select t.ok((public.master_get_session(:'ta')->'notes'->'roteiro'->>'text') = 'segredo do mestre', 'notas do mestre persistidas');
select t.ok((public.master_get_session(:'ta')->'state'->'clocks'->0->>'id') = 'c1', 'estado persistido');

-- Segunda aba com a versão antiga: recusada como conflito, nada sobrescrito
select t.ok((public.master_save_session(:'ta', '{"clocks":[]}', null, 0)->>'conflict')::boolean, 'versão antiga = conflito');
select t.ok((public.master_get_session(:'ta')->'state'->'clocks'->0->>'id') = 'c1', 'conflito não sobrescreve o estado mais recente');

-- p_notes null mantém as notas
select public.master_save_session(:'ta', '{"clocks":[{"id":"c2"}]}', null, 1);
select t.ok((public.master_get_session(:'ta')->'notes'->'roteiro'->>'text') = 'segredo do mestre', 'salvar sem notas preserva as notas');
select t.ok((public.master_get_session(:'ta')->>'version')::bigint = 2, 'versão 2 após segunda gravação');

-- Update direto (cliente antigo) também avança a versão -> o cliente novo detecta conflito
update public.tables set session_state = '{"clocks":[{"id":"velho"}]}' where id = :'ta';
select t.ok((public.master_get_session(:'ta')->>'version')::bigint = 3, 'update direto de cliente antigo avança a versão');
select t.ok((public.master_save_session(:'ta', '{"clocks":[]}', null, 2)->>'conflict')::boolean, 'cliente novo detecta a escrita do cliente antigo');

-- Mesas isoladas: gravar em B não muda A
select public.master_save_session(:'tb', '{"clocks":[{"id":"daB"}]}', '{"roteiro":{"text":"B"}}', 0);
select t.ok((public.master_get_session(:'ta')->'state'->'clocks'->0->>'id') = 'velho', 'gravação em B não altera A');
select t.ok((public.master_get_session(:'tb')->'notes'->'roteiro'->>'text') = 'B', 'notas de B independentes');

-- Validação de payload
select t.fails(format($$select public.master_save_session(%L, '[]', null, 3)$$, t.v('ta')), 'estado precisa ser objeto', 'invalid_state');

-- Status: pausar / encerrar; valores livres recusados
select t.ok((public.master_set_status(:'ta','Pausada · retomar depois')->>'ok')::boolean, 'mestre pausa');
select t.ok((select status from public.tables where id=:'ta') = 'Pausada · retomar depois', 'pausa persistida');
select t.fails(format($$select public.master_set_status(%L,'Em andamento')$$, t.v('ta')), 'retomar não passa por set_status (guarda de aprovação)', 'invalid_status');

-- Jogador entra: projeção não leva notas do mestre
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as toka from public.join_table_by_code('SV-P301','Ana') \gset
select t.ok(not (public.player_get_session(:'ma', :'toka')::text like '%segredo do mestre%'), 'notas do mestre não chegam ao jogador');
select t.ok((public.player_get_state(:'ma', :'toka')->>'table_status') = 'Pausada · retomar depois', 'jogador enxerga o status pausado');
select t.fails(format($$select public.master_get_session(%L)$$, t.v('ta')), 'anon não lê sessão do mestre', 'permission denied');
select t.fails(format($$select public.master_save_session(%L,'{}',null,0)$$, t.v('ta')), 'anon não grava sessão', 'permission denied');
select t.fails(format($$select public.master_set_status(%L,'Encerrada')$$, t.v('ta')), 'anon não muda status', 'permission denied');
select t.ok((select count(*) from public.tables) = 0, 'anon não enxerga nenhuma mesa (nem notas) por select direto');

-- Outro usuário logado: nada
reset role; set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.fails(format($$select public.master_get_session(%L)$$, t.v('ta')), 'outro usuário não lê a sessão', 'not_authorized');
select t.fails(format($$select public.master_save_session(%L,'{}',null,3)$$, t.v('ta')), 'outro usuário não grava', 'not_authorized');
select t.fails(format($$select public.master_set_status(%L,'Encerrada')$$, t.v('ta')), 'outro usuário não encerra', 'not_authorized');
select t.ok((select count(*) from public.tables where master_notes <> '{}'::jsonb) = 0, 'outro usuário não vê notas por select direto');

-- Biblioteca por conta
reset role;
select t.ok((select count(*) from public.profiles where id in ('11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333')) = 2, 'perfil criado pelo trigger de cadastro');
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
update public.profiles set master_library = '{"weapons":[{"id":"w9","name":"Navalha"}],"wounds":["Corte"],"conditions":["Febril"]}' where id = auth.uid();
select t.ok((select master_library->'wounds'->>0 from public.profiles where id = auth.uid()) = 'Corte', 'mestre grava a própria biblioteca');
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.ok((select count(*) from public.profiles where master_library <> '{}'::jsonb) = 0, 'outro usuário não lê a biblioteca do mestre');
update public.profiles set master_library = '{}' where id = '11111111-1111-1111-1111-111111111111';
reset role;
select t.ok((select master_library->'wounds'->>0 from public.profiles where id = '11111111-1111-1111-1111-111111111111') = 'Corte', 'outro usuário não altera a biblioteca do mestre');

select t.ok(not has_function_privilege('anon','public.master_save_session(uuid,jsonb,jsonb,bigint)','execute'), 'master_save_session fechado p/ anon');
select t.ok(not has_function_privilege('authenticated','public._ad_tables_version()','execute'), 'trigger de versão fechado');
\echo 'TODOS OS TESTES DO PONTO 3 PASSARAM'
