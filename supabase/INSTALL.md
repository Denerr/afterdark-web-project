# Afterdark — Instalação do banco

As migrações são **incrementais e dependentes de ordem**. Algumas corrigem policies criadas por arquivos anteriores — por exemplo, `schema.sql` cria um `tables_select_own` permissivo que `migration_rls_hardening.sql` substitui, e `migration_table_members.sql` cria `members_select_all` que `migration_rls_p2.sql` remove.

**Rodar fora de ordem, ou parar no meio, deixa o banco com permissões abertas.**

## Ordem obrigatória

```
 1. schema.sql
 2. migration_invite_code.sql
 3. migration_table_members.sql
 4. migration_session_state.sql
 5. migration_rls_hardening.sql
 6. migration_leave_table.sql
 7. migration_archive_table.sql
 8. migration_profiles.sql
 9. migration_requests_consequences.sql     <- Ponto 1
10. migration_rls_p2.sql                    <- Ponto 2 (precisa ser o último)
```

Todas são idempotentes: rodar de novo não duplica objeto.

## Instalação nova (Supabase)

SQL Editor > New query > colar e executar **um arquivo por vez**, na ordem acima.

## Instalação nova (Postgres local, para teste)

```bash
export MSYS_NO_PATHCONV=1   # só no Git Bash do Windows
docker run -d --name adpg -e POSTGRES_PASSWORD=pg postgres:15

cat tests/00_stub_supabase.sql schema.sql migration_invite_code.sql \
    migration_table_members.sql migration_session_state.sql \
    migration_rls_hardening.sql migration_leave_table.sql \
    migration_archive_table.sql migration_profiles.sql \
    migration_requests_consequences.sql migration_rls_p2.sql > /tmp/all.sql

docker cp /tmp/all.sql adpg:/tmp/all.sql
docker exec adpg psql -U postgres -q -f /tmp/all.sql
```

`tests/00_stub_supabase.sql` recria só o mínimo do ambiente Supabase (`auth.users`, `auth.uid()`, papéis `anon`/`authenticated`) para o banco local aceitar as migrações. **Não** rodar esse arquivo no Supabase real.

## Atualizar um banco que já existe

Rodar apenas o que ainda não passou. Para um banco que já tinha até o Ponto 1, basta `migration_rls_p2.sql`.

Depois de aplicar o Ponto 2, confirmar que não sobrou policy permissiva:

```sql
select tablename, policyname, cmd, qual
  from pg_policies
 where schemaname = 'public'
   and (qual = 'true' or qual is null)
 order by tablename, policyname;
```

Esperado: nenhuma linha para `table_members`, `table_requests`, `tables`, `characters` e `profiles`.

E que as três funções antigas e abertas sumiram:

```sql
select proname from pg_proc
 where pronamespace = 'public'::regnamespace
   and proname in ('get_table_session_state','get_table_status','get_table_by_invite_code');
```

Esperado: nenhuma linha.

## Testes

```bash
for suite in ponto1_tests ponto2_tests; do
  docker rm -f adpg >/dev/null 2>&1
  docker run -d --name adpg -e POSTGRES_PASSWORD=pg postgres:15 >/dev/null
  until docker exec adpg pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
  docker cp /tmp/all.sql adpg:/tmp/all.sql
  docker cp "tests/$suite.sql" adpg:/tmp/t.sql
  docker exec adpg psql -U postgres -q -f /tmp/all.sql >/dev/null
  echo "== $suite =="
  docker exec adpg psql -U postgres -q -f /tmp/t.sql 2>&1 | grep -cE "PASSOU"
  docker exec adpg psql -U postgres -q -f /tmp/t.sql 2>&1 | grep -E "FALHOU|TODOS"
done
docker rm -f adpg
```

Esperado: **52 PASSOU** no Ponto 1 e **71 PASSOU** no Ponto 2.

Cada arquivo cria o schema `t`, então **cada suíte precisa de uma base recém-criada** — rodar as duas na mesma base falha na segunda. Recriar o container entre elas.

Os testes do Ponto 1 são a regressão da etapa anterior e precisam continuar passando depois do Ponto 2.
