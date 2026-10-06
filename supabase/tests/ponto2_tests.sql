-- Testes SQL do Ponto 2 (Postgres local via Docker; nao toca no Supabase real).
--   export MSYS_NO_PATHCONV=1   # só no Git Bash do Windows
--   docker run -d --name adpg -e POSTGRES_PASSWORD=pg postgres:15
--   cat tests/00_stub_supabase.sql schema.sql migration_invite_code.sql migration_table_members.sql \
--       migration_session_state.sql migration_rls_hardening.sql migration_leave_table.sql \
--       migration_archive_table.sql migration_profiles.sql migration_requests_consequences.sql \
--       migration_rls_p2.sql > /tmp/all.sql
--   docker cp /tmp/all.sql adpg:/tmp/all.sql && docker cp tests/ponto2_tests.sql adpg:/tmp/t2.sql
--   docker exec adpg psql -U postgres -q -f /tmp/all.sql
--   docker exec adpg psql -U postgres -q -f /tmp/t2.sql | grep -E "PASSOU|FALHOU|TODOS"
--   docker rm -f adpg
-- Rodar numa base limpa (sem o ponto1_tests.sql antes, que cria o schema t).
-- Esperado: 71 linhas PASSOU e 'TODOS OS TESTES DO PONTO 2 PASSARAM'.
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

-- M = mestre dono, N = outro mestre (mesa própria), X = usuário logado sem mesa
insert into auth.users(id) values
 ('11111111-1111-1111-1111-111111111111'),
 ('22222222-2222-2222-2222-222222222222'),
 ('33333333-3333-3333-3333-333333333333');

-- ---------------------------------------------------------------------------
-- Cenário: M tem a Mesa A (com jogadores) e a Mesa B (vazia). N tem a Mesa N.
-- ---------------------------------------------------------------------------
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa A','SV-P2AA') returning id as ta \gset
insert into public.tables(name, invite_code) values ('Mesa B','SV-P2BB') returning id as tb \gset
reset role; set role authenticated; select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
insert into public.tables(name, invite_code) values ('Mesa N','SV-P2NN') returning id as tn \gset
select set_config('t.ta', :'ta', false), set_config('t.tb', :'tb', false), set_config('t.tn', :'tn', false);

-- Visitantes: A e B na Mesa A; C na Mesa N
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as toka from public.join_table_by_code('SV-P2AA','Ana') \gset
select member_id as mb, member_token as tokb from public.join_table_by_code('sv-p2aa','Bia') \gset
select member_id as mc, member_token as tokc from public.join_table_by_code('SV-P2NN','Caio') \gset
select set_config('t.ma', :'ma', false), set_config('t.toka', :'toka', false),
       set_config('t.mb', :'mb', false), set_config('t.tokb', :'tokb', false),
       set_config('t.mc', :'mc', false), set_config('t.tokc', :'tokc', false);
select t.ok(length(t.v('toka')) = 64, 'ingresso por convite válido continua funcionando');
select t.fails($$select public.join_table_by_code('SV-NOPE','x')$$, 'código inválido não expõe dados', 'invalid_code');

-- Fichas concluídas, com conteúdo privado (atributos/perícias/histórico)
select public.player_submit_sheet(:'ma', :'toka', 'Ana', 'Kara',
  '{"sens":"vidente","attrs":{"mente":3},"skills":{"analise":2},"weaknesses":["Insônia"],"history":"SEGREDO-DA-ANA"}');
select public.player_submit_sheet(:'mb', :'tokb', 'Bia', 'Rook',
  '{"sens":"farejador","attrs":{"corpo":3},"skills":{"luta":2},"weaknesses":["Fúria"],"history":"SEGREDO-DA-BIA"}');

-- ---------------------------------------------------------------------------
-- 1) Acesso direto a table_members está fechado
-- ---------------------------------------------------------------------------
select t.fails($$select * from public.table_members$$, 'anon não lê table_members', 'permission denied');
select t.fails(format($$update public.table_members set player_name='hack' where id=%L$$, t.v('mb')),
  'anon não altera membro', 'permission denied');
select t.fails(format($$delete from public.table_members where id=%L$$, t.v('mb')),
  'anon não remove membro', 'permission denied');
select t.fails(format($$insert into public.table_members(table_id, player_name) values (%L,'Intruso')$$, t.v('ta')),
  'anon não insere membro direto (só por join_table_by_code)', 'permission denied|violates row-level');
select t.fails($$select * from public.table_member_secrets$$, 'anon não lê os segredos', 'permission denied');

-- Usuário logado que não é dono: tem grant, mas a policy não devolve linha nenhuma
reset role; set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select t.ok((select count(*) from public.table_members)=0, 'usuário sem vínculo não lê nenhum membro');
select t.ok((select count(*) from public.tables)=0, 'usuário sem vínculo não lista mesas');
select t.ok((select count(*) from public.table_requests)=0, 'usuário sem vínculo não lê solicitações');

-- Outro mestre só vê a própria mesa e os próprios membros
reset role; set role authenticated; select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
select t.ok((select count(*) from public.tables)=1, 'outro mestre vê só a mesa dele');
select t.ok((select count(*) from public.table_members)=1, 'outro mestre vê só os membros da mesa dele');
select t.ok((select count(*) from public.table_members where id=t.v('ma')::uuid)=0, 'mesa N não alcança membro da mesa A');
-- A RLS não levanta erro num UPDATE/DELETE: ela filtra as linhas, então a escrita
-- afeta 0 linhas. O que se verifica aqui é o efeito, não uma exceção.
update public.table_members set approved_at=now(), status='pronto' where id=t.v('ma')::uuid;
delete from public.table_members where id=t.v('mb')::uuid;
-- insert, ao contrário, é recusado: table_members não tem policy de insert
select t.fails(format($$insert into public.table_members(table_id, player_name) values (%L,'Intruso')$$, t.v('ta')),
  'usuário logado não insere membro em mesa alheia', 'violates row-level security');
reset role;
select t.ok((select approved_at is null and status <> 'pronto' from public.table_members where id=t.v('ma')::uuid),
  'update de outro mestre não alcança a linha da mesa A');
select t.ok((select count(*) from public.table_members where id=t.v('mb')::uuid)=1,
  'delete de outro mestre não alcança a linha da mesa A');

-- O dono continua lendo e escrevendo a própria mesa
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
select t.ok((select count(*) from public.table_members where table_id=t.v('ta')::uuid)=2, 'dono lê os 2 membros da própria mesa');
select t.ok((public.master_set_approval(t.v('ma')::uuid, true)->>'ok')::boolean, 'dono aprova normalmente');
select t.ok((public.master_member_consequence(t.v('mb')::uuid,'add_wound','{"lvl":"leve","desc":"Corte no braço"}')->>'ok')::boolean,
  'dono aplica ferimento normalmente');
select public.master_member_consequence(t.v('mb')::uuid,'add_condition','{"name":"Abalada"}');
-- O trigger _ad_members_guard continua vivo no caminho do dono: nem ele move um
-- membro para outra mesa (reatribuição de vínculo).
select t.fails(format($$update public.table_members set table_id=%L where id=%L$$, t.v('tb'), t.v('ma')),
  'nem o dono reatribui um membro para outra mesa', 'table_id não pode ser alterado');

-- ---------------------------------------------------------------------------
-- 2) Funções antigas e permissivas foram removidas
-- ---------------------------------------------------------------------------
select t.ok((select count(*) from pg_proc where pronamespace='public'::regnamespace
  and proname in ('get_table_session_state','get_table_status','get_table_by_invite_code'))=0,
  'get_table_session_state / get_table_status / get_table_by_invite_code removidas');

-- ---------------------------------------------------------------------------
-- 3) Nenhuma policy permissiva sobrou (instalação limpa reproduz o estado final)
-- ---------------------------------------------------------------------------
reset role;
-- Policy permissiva = expressão literalmente 'true'. Policy de INSERT tem qual
-- nulo por natureza (ela usa with_check), então nulo aqui não é sinal de problema.
select t.ok((select count(*) from pg_policies where schemaname='public'
  and tablename in ('tables','table_members','table_requests','characters','profiles')
  and (qual='true' or with_check='true'))=0, 'nenhuma policy permissiva (true) nas tabelas de mesa');
select t.ok((select count(*) from pg_policies where schemaname='public'
  and tablename in ('tables','table_members','table_requests','characters','profiles')
  and coalesce(qual, with_check) is null)=0, 'toda policy dessas tabelas tem expressão de autorização');
select t.ok((select count(*) from pg_policies where schemaname='public'
  and tablename='table_members' and cmd='INSERT')=0, 'table_members sem policy de insert');
select t.ok((select count(*) from pg_policies where schemaname='public' and tablename='table_member_secrets')=0,
  'table_member_secrets sem policy nenhuma');

-- ---------------------------------------------------------------------------
-- 4) O mestre escreve um session_state com conteúdo reservado
-- ---------------------------------------------------------------------------
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
update public.tables set session_state = jsonb_build_object(
  'clocks', jsonb_build_array(
     jsonb_build_object('id','c-pub','name','RELOGIO-PUBLICO','vis','todos','fill',1,'seg',8),
     jsonb_build_object('id','c-sec','name','RELOGIO-SECRETO','vis','mestre','fill',3,'seg',8),
     jsonb_build_object('id','c-ana','name','RELOGIO-DA-ANA','vis','jogador','playerId',t.v('ma'),'fill',2,'seg',4),
     jsonb_build_object('id','c-bia','name','RELOGIO-DA-BIA','vis','jogador','playerId',t.v('mb'),'fill',1,'seg',4)),
  'npcs', jsonb_build_array(
     jsonb_build_object('id','n1','name','NPC-REVELADO','reveal',4,'theme','vampiro'),
     jsonb_build_object('id','n2','name','NPC-OCULTO','reveal',1,'theme','vampiro')),
  'clues', jsonb_build_array(
     jsonb_build_object('id','k1','name','PISTA-ENCONTRADA','status','encontrada'),
     jsonb_build_object('id','k2','name','PISTA-OCULTA','status','oculta')),
  'stressBars', jsonb_build_array(
     jsonb_build_object('id','s1','name','ESTRESSE-DA-ANA','playerId',t.v('ma'),'level',1,'max',4),
     jsonb_build_object('id','s2','name','ESTRESSE-DA-BIA','playerId',t.v('mb'),'level',2,'max',4),
     jsonb_build_object('id','s3','name','ESTRESSE-DA-MESA','playerId','','level',0,'max',4)),
  'log', jsonb_build_array(
     jsonb_build_object('icon','◷','t','Relógio','txt','LOG-PUBLICO','vis','todos'),
     jsonb_build_object('icon','💾','t','Mesa','txt','LOG-DO-MESTRE','vis','mestre'),
     jsonb_build_object('icon','⚄','t','Teste','txt','LOG-PRIVADO-ANA','vis',t.v('ma')),
     jsonb_build_object('icon','⚄','t','Teste','txt','LOG-PRIVADO-BIA','vis',t.v('mb')),
     jsonb_build_object('icon','⚄','t','Teste','txt','LOG-LEGADO-SEM-VIS')),
  'scene', jsonb_build_object('local','Beco','clima','Chuva'),
  'inventory', jsonb_build_object('items', jsonb_build_array('i1')),
  'library', jsonb_build_object('weapons', jsonb_build_array())
) where id = t.v('ta')::uuid;

-- ---------------------------------------------------------------------------
-- 5) player_get_session filtra no banco, por destinatário
-- ---------------------------------------------------------------------------
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select set_config('t.sa', public.player_get_session(t.v('ma')::uuid, t.v('toka'))::text, false);
select set_config('t.sb', public.player_get_session(t.v('mb')::uuid, t.v('tokb'))::text, false);

-- relógios
select t.ok(t.v('sa') like '%RELOGIO-PUBLICO%', 'Ana recebe o relógio da mesa');
select t.ok(t.v('sa') not like '%RELOGIO-SECRETO%', 'relógio oculto do mestre NÃO chega ao jogador');
select t.ok(t.v('sa') like '%RELOGIO-DA-ANA%', 'Ana recebe o relógio dirigido a ela');
select t.ok(t.v('sa') not like '%RELOGIO-DA-BIA%', 'Ana NÃO recebe o relógio dirigido à Bia');
select t.ok(t.v('sb') like '%RELOGIO-DA-BIA%', 'Bia recebe o relógio dirigido a ela');
select t.ok(jsonb_array_length(t.v('sa')::jsonb->'clocks')=2, 'Ana recebe exatamente 2 relógios');

-- NPCs
select t.ok(t.v('sa') like '%NPC-REVELADO%', 'NPC revelado (reveal>=3) chega ao jogador');
select t.ok(t.v('sa') not like '%NPC-OCULTO%', 'NPC não revelado NÃO chega ao jogador');

-- pistas
select t.ok(t.v('sa') like '%PISTA-ENCONTRADA%', 'pista encontrada chega ao jogador');
select t.ok(t.v('sa') not like '%PISTA-OCULTA%', 'pista oculta NÃO chega ao jogador');

-- estresse
select t.ok(t.v('sa') like '%ESTRESSE-DA-ANA%', 'Ana recebe a própria barra de estresse');
select t.ok(t.v('sa') not like '%ESTRESSE-DA-BIA%', 'Ana NÃO recebe a barra de estresse da Bia');
select t.ok(t.v('sa') like '%ESTRESSE-DA-MESA%', 'barra de estresse sem dono é da mesa');

-- log
select t.ok(t.v('sa') like '%LOG-PUBLICO%', 'log da mesa chega ao jogador');
select t.ok(t.v('sa') not like '%LOG-DO-MESTRE%', 'log do mestre NÃO chega ao jogador');
select t.ok(t.v('sa') like '%LOG-PRIVADO-ANA%', 'Ana recebe o log privado dela');
select t.ok(t.v('sa') not like '%LOG-PRIVADO-BIA%', 'Ana NÃO recebe o log privado da Bia');
select t.ok(t.v('sa') not like '%LOG-LEGADO-SEM-VIS%', 'log legado sem vis NÃO chega ao jogador');
select t.ok(jsonb_array_length(t.v('sa')::jsonb->'log')=2, 'Ana recebe exatamente 2 entradas de log');

-- conteúdo público íntegro
select t.ok(t.v('sa')::jsonb->'scene'->>'local'='Beco', 'cena pública chega íntegra');

-- autorização do próprio estado da sessão
select t.fails(format($$select public.player_get_session(%L,'token-errado')$$, t.v('ma')),
  'token errado não abre o estado da sessão', 'not_authorized');
select t.fails(format($$select public.player_get_session(%L,%L)$$, t.v('ma'), t.v('tokb')),
  'token da Bia não abre o estado da Ana', 'not_authorized');
select t.fails(format($$select public.player_get_session(%L,%L)$$, t.v('mc'), t.v('toka')),
  'jogador da mesa A não alcança a mesa N trocando o member_id', 'not_authorized');
select t.ok(public.player_get_session(t.v('mc')::uuid, t.v('tokc'))::text not like '%RELOGIO%',
  'jogador da mesa N não recebe nada da mesa A');

-- ---------------------------------------------------------------------------
-- 6) player_get_lobby: colegas com consequências, sem ficha privada
-- ---------------------------------------------------------------------------
select set_config('t.la', public.player_get_lobby(t.v('ma')::uuid, t.v('toka'))::text, false);
select t.ok(t.v('la') like '%Rook%', 'Ana vê o personagem da Bia no lobby');
select t.ok(t.v('la') like '%Corte no braço%', 'Ana vê os ferimentos da Bia (decisão desta etapa)');
select t.ok(t.v('la') like '%Abalada%', 'Ana vê as condições da Bia');
select t.ok(t.v('la') like '%farejador%', 'Ana vê a natureza da Bia');
select t.ok(t.v('la') not like '%SEGREDO-DA-BIA%', 'Ana NÃO vê o histórico da Bia');
select t.ok(t.v('la') not like '%Fúria%', 'Ana NÃO vê as fraquezas da Bia');
select t.ok(t.v('la') not like '%"luta"%', 'Ana NÃO vê as perícias da Bia');
select t.ok(t.v('la')::jsonb->>'table_status' is not null, 'lobby devolve o status da mesa');
select t.fails(format($$select public.player_get_lobby(%L,%L)$$, t.v('mc'), t.v('toka')),
  'token da mesa A não abre o lobby da mesa N', 'not_authorized');

-- A própria ficha continua inteira para o dono dela
select t.ok(public.player_get_state(t.v('mb')::uuid, t.v('tokb'))::text like '%SEGREDO-DA-BIA%',
  'Bia continua vendo a própria ficha inteira');
select t.ok(public.player_get_state(t.v('ma')::uuid, t.v('toka'))->>'table_status' is not null,
  'player_get_state devolve o status da mesa (substitui get_table_status)');

-- ---------------------------------------------------------------------------
-- 7) Visitante não mexe em outro visitante, nem em campo reservado
-- ---------------------------------------------------------------------------
select t.fails(format($$select public.player_submit_sheet(%L,%L,'x','Hack','{}'::jsonb)$$, t.v('mb'), t.v('toka')),
  'Ana não grava a ficha da Bia', 'not_authorized');
select t.fails(format($$select public.player_set_ready(%L,%L,true)$$, t.v('mb'), t.v('toka')),
  'Ana não marca a Bia como pronta', 'not_authorized');
select t.fails(format($$select public.player_leave_table(%L,%L)$$, t.v('mb'), t.v('toka')),
  'Ana não remove a Bia da mesa', 'not_authorized');
select t.fails(format($$select public.master_set_approval(%L,true)$$, t.v('mb')),
  'visitante não aprova ninguém', 'permission denied');
select t.fails(format($$select public.master_start_session(%L)$$, t.v('ta')),
  'visitante não inicia a sessão', 'permission denied');

-- Jogador LOGADO e vinculado também não lê table_members direto: ele tem grant,
-- mas a policy é só do dono. O caminho dele é player_get_lobby / player_get_state.
reset role; set role authenticated; select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select member_id as ml from public.join_table_by_code('SV-P2AA','Leo') \gset
select set_config('t.ml', :'ml', false);
select t.ok((select count(*) from public.table_members)=0, 'jogador logado e vinculado não lê table_members direto');
select t.ok((public.player_get_state(t.v('ml')::uuid, null)->'member'->>'id')=t.v('ml'), 'jogador logado lê o próprio estado por função');
select t.ok(public.player_get_lobby(t.v('ml')::uuid, null)::text like '%Kara%', 'jogador logado vê os colegas por função');
select t.ok(public.player_get_session(t.v('ml')::uuid, null)::text not like '%RELOGIO-SECRETO%', 'jogador logado também não recebe o relógio do mestre');

-- Sair da própria mesa funciona
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select t.ok((public.player_leave_table(t.v('mc')::uuid, t.v('tokc'))->>'ok')::boolean, 'jogador sai da própria mesa');
reset role;
select t.ok((select count(*) from public.table_members where id=t.v('mc')::uuid)=0, 'saída removeu o membro');

select 'TODOS OS TESTES DO PONTO 2 PASSARAM' as resultado;
