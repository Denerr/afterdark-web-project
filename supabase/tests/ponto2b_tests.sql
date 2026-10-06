-- Testes SQL: relogios e estresse na projecao do jogador (plano 2.1-2.4).
-- Rodar numa base limpa, com as migracoes na ordem do INSTALL.md.
--   docker exec adpg psql -U postgres -q -f /tmp/all.sql
--   docker exec adpg psql -U postgres -q -f /tmp/t2b.sql | grep -E "PASSOU|FALHOU|TODOS"
-- Esperado: 24 linhas PASSOU e 'TODOS OS TESTES 2B PASSARAM'.
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

insert into auth.users(id) values ('11111111-1111-1111-1111-111111111111');

set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into public.tables(name, invite_code) values ('Mesa 2B','SV-2B01') returning id as ta \gset
select set_config('t.ta', :'ta', false);

reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as toka from public.join_table_by_code('SV-2B01','Ana') \gset
select member_id as mb, member_token as tokb from public.join_table_by_code('SV-2B01','Bia') \gset
select set_config('t.ma',:'ma',false), set_config('t.toka',:'toka',false),
       set_config('t.mb',:'mb',false), set_config('t.tokb',:'tokb',false);
select public.player_submit_sheet(:'ma',:'toka','Ana','Kara','{"sens":"vampiros"}');
select public.player_submit_sheet(:'mb',:'tokb','Bia','Rook','{"sens":"lobisomens"}');

-- O mestre grava relogios e barras cobrindo todos os estados de visibilidade
reset role; set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
update public.tables set session_state = jsonb_build_object(
  'clocks', jsonb_build_array(
     jsonb_build_object('id','c-pub','name','CLK-PUBLICO','vis','todos','visMode','todos','scope','mesa','fill',2,'seg',6),
     jsonb_build_object('id','c-sec','name','CLK-SECRETO','vis','mestre','visMode','mestre','scope','mesa','fill',3,'seg',6),
     jsonb_build_object('id','c-ana','name','CLK-DA-ANA','vis','jogador','visMode','jogador','scope','player','playerId',t.v('ma'),'fill',1,'seg',4),
     jsonb_build_object('id','c-bia','name','CLK-DA-BIA','vis','jogador','visMode','jogador','scope','player','playerId',t.v('mb'),'fill',2,'seg',4),
     jsonb_build_object('id','c-gat','name','CLK-GATILHO','vis','mestre','visMode','avancar','scope','mesa','fill',0,'seg',4)),
  'stressBars', jsonb_build_array(
     jsonb_build_object('id','s-pub','name','BARRA-PUBLICA','playerId',t.v('ma'),'level',1,'max',4,'vis','todos'),
     jsonb_build_object('id','s-ana','name','BARRA-DA-ANA','playerId',t.v('ma'),'level',2,'max',4,'vis','titular'),
     jsonb_build_object('id','s-bia','name','BARRA-DA-BIA','playerId',t.v('mb'),'level',1,'max',4,'vis','titular'),
     jsonb_build_object('id','s-mst','name','BARRA-SO-MESTRE','playerId',t.v('ma'),'level',3,'max',4,'vis','mestre'),
     jsonb_build_object('id','s-leg','name','BARRA-LEGADA-DA-ANA','playerId',t.v('ma'),'level',1,'max',4),
     jsonb_build_object('id','s-orf','name','BARRA-LEGADA-SEM-DONO','playerId','','level',1,'max',4),
     jsonb_build_object('id','s-vsec','name','BARRA-VINC-SECRETO','playerId',t.v('ma'),'level',1,'max',4,'vis','todos','clockId','c-sec'),
     jsonb_build_object('id','s-vpub','name','BARRA-VINC-PUBLICO','playerId',t.v('ma'),'level',1,'max',4,'vis','todos','clockId','c-pub')),
  'npcs', '[]'::jsonb, 'clues', '[]'::jsonb, 'log', '[]'::jsonb,
  'scene', jsonb_build_object('local','Beco'), 'inventory', '{}'::jsonb, 'library', '{}'::jsonb
) where id = t.v('ta')::uuid;

reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select set_config('t.sa', public.player_get_session(t.v('ma')::uuid, t.v('toka'))::text, false);
select set_config('t.sb', public.player_get_session(t.v('mb')::uuid, t.v('tokb'))::text, false);

-- ---------------------------------------------------------------- relogios
select t.ok(t.v('sa') like '%CLK-PUBLICO%', 'relogio publico chega ao jogador');
select t.ok(t.v('sa') not like '%CLK-SECRETO%', 'relogio oculto do mestre NAO chega');
select t.ok(t.v('sa') like '%CLK-DA-ANA%', 'relogio individual chega ao titular');
select t.ok(t.v('sa') not like '%CLK-DA-BIA%', 'relogio individual de outro NAO chega');
select t.ok(t.v('sb') like '%CLK-DA-BIA%', 'cada titular recebe o seu');
select t.ok(t.v('sa') not like '%CLK-GATILHO%', 'relogio de gatilho segue oculto antes de disparar');
select t.ok(jsonb_array_length(t.v('sa')::jsonb->'clocks')=2, 'Ana recebe exatamente 2 relogios');

-- --------------------------------------------------------------- estresse
select t.ok(t.v('sa') like '%BARRA-PUBLICA%', 'barra publica chega ao titular');
select t.ok(t.v('sb') like '%BARRA-PUBLICA%', 'barra publica chega aos colegas');
select t.ok(t.v('sa') like '%BARRA-DA-ANA%', 'barra do titular chega a ele');
select t.ok(t.v('sb') not like '%BARRA-DA-ANA%', 'barra do titular NAO chega ao colega');
select t.ok(t.v('sb') like '%BARRA-DA-BIA%', 'cada titular recebe a sua');
select t.ok(t.v('sa') not like '%BARRA-SO-MESTRE%', 'barra so do mestre NAO chega nem ao titular');
select t.ok(t.v('sa') like '%BARRA-LEGADA-DA-ANA%', 'barra legada sem vis vale como titular (chega ao dono)');
select t.ok(t.v('sb') not like '%BARRA-LEGADA-DA-ANA%', 'barra legada NAO vaza para a mesa (padrao conservador)');
select t.ok(t.v('sa') not like '%BARRA-LEGADA-SEM-DONO%', 'barra legada sem dono nao chega a ninguem');
select t.ok(t.v('sb') not like '%BARRA-LEGADA-SEM-DONO%', 'barra legada sem dono tambem nao chega ao colega');

-- -------------------------------------------- vinculo com relogio invisivel
select t.ok(t.v('sa') like '%BARRA-VINC-SECRETO%', 'barra publica vinculada a relogio oculto ainda chega');
select t.ok(t.v('sa') not like '%c-sec%', 'o clockId do relogio oculto e REMOVIDO da barra');
select t.ok(t.v('sa') like '%c-pub%', 'o clockId de relogio visivel e preservado');
select t.ok((select count(*) from jsonb_array_elements(t.v('sa')::jsonb->'stressBars') b
             where b->>'id'='s-vsec' and b ? 'clockId')=0, 'a chave clockId nem existe na barra limpa');
select t.ok((select count(*) from jsonb_array_elements(t.v('sa')::jsonb->'stressBars') b
             where b->>'id'='s-vpub' and b->>'clockId'='c-pub')=1, 'barra com relogio visivel mantem o vinculo');

-- ------------------------------------------------------------- autorizacao
select t.fails(format($q$select public.player_get_session(%L,'errado')$q$, t.v('ma')),
  'token errado nao abre o estado', 'not_authorized');
select t.ok(public.player_get_session(t.v('mb')::uuid, t.v('tokb'))::text not like '%CLK-DA-ANA%',
  'troca de identidade nao traz conteudo de outro membro');

select 'TODOS OS TESTES 2B PASSARAM' as resultado;
