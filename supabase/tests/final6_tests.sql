-- Testes SQL da Etapa 6 do plano final (migration_final_objectives.sql): objetivos.
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
insert into public.tables(name, invite_code) values ('Mesa F6','SV-F6AA') returning id as tid \gset
reset role; set role anon; select set_config('request.jwt.claim.sub','',false);
select member_id as ma, member_token as ta from public.join_table_by_code('SV-F6AA','Ana') \gset
reset role;
update public.tables set session_state = jsonb_build_object('objectives', jsonb_build_array(
  jsonb_build_object('id','o3','text','Fugir pelo cais','order',3,'status','andamento','shared',true),
  jsonb_build_object('id','o1','text','Achar o comprador','order',1,'status','concluido','shared',true,'notes','NOTA-PRIVADA'),
  jsonb_build_object('id','o2','text','Proteger a testemunha','order',2,'status','falhou','shared',true),
  jsonb_build_object('id','oS','text','OBJETIVO-SECRETO','order',0,'status','andamento','shared',false))) where id = :'tid';
set role anon;
select public.player_get_session(:'ma', :'ta') as st \gset
select t.ok((select string_agg(o->>'id', ',' order by ord) from jsonb_array_elements(:'st'::jsonb->'objectives') with ordinality as x(o, ord)) = 'o1,o2,o3', 'jogador recebe os objetivos do grupo na ordem do Mestre');
select t.ok((:'st'::jsonb->'objectives'->0->>'status') = 'concluido' and (:'st'::jsonb->'objectives'->1->>'status') = 'falhou', 'status chega (concluído / falhou)');
select t.ok(:'st' not like '%NOTA-PRIVADA%' and :'st' not like '%OBJETIVO-SECRETO%', 'notas privadas e objetivo não compartilhado não chegam');
select t.fails(format($$select public.master_save_session(%L,'{}','{}',0)$$, :'tid'), 'jogador não grava objetivos (sem acesso à escrita do Mestre)', 'not_authorized|permission denied');
do $$ begin raise notice 'TODOS OS TESTES SQL PASSARAM'; end $$;
