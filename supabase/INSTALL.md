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
10. migration_rls_p2.sql                    <- Ponto 2
11. migration_player_projection.sql         <- relógios/estresse/grupo
12. migration_session_persistence.sql       <- Ponto 3
13. migration_skill_pairs.sql               <- UI Etapa 5: par atributo/perícia (último)
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
    migration_requests_consequences.sql migration_rls_p2.sql \
    migration_player_projection.sql migration_session_persistence.sql \
    migration_skill_pairs.sql > /tmp/all.sql

docker cp /tmp/all.sql adpg:/tmp/all.sql
docker exec adpg psql -U postgres -q -f /tmp/all.sql
```

`tests/00_stub_supabase.sql` recria só o mínimo do ambiente Supabase (`auth.users`, `auth.uid()`, papéis `anon`/`authenticated`) para o banco local aceitar as migrações. **Não** rodar esse arquivo no Supabase real.

## Atualizar um banco que já existe

Rodar apenas o que ainda não passou. Para um banco que já tinha até o Ponto 1, rodar `migration_rls_p2.sql` e depois
`migration_player_projection.sql`. Para um banco que já está no Ponto 2, basta
`migration_player_projection.sql`.

Para um banco que já tem a `migration_player_projection.sql`, basta
`migration_session_persistence.sql` (Ponto 3). Ela só **adiciona** colunas
(`tables.session_version`, `tables.master_notes`, `profiles.master_library`), um trigger
de versão e três funções do Mestre; não altera policy nem grant. A ordem entre deploy e
migração é livre **nesse sentido**: o cliente antigo continua funcionando depois dela.
Mas o cliente do Ponto 3 chama `master_get_session`/`master_save_session`, então
**aplique a migração antes (ou junto) do deploy** — sem ela o Mestre não carrega a mesa.

Para um banco que já tem a `migration_session_persistence.sql`, basta
`migration_skill_pairs.sql` (UI Etapa 5). Ela substitui `master_create_request` e cria a
tabela de pares `_ad_skill_attr`, fechada para a API. A tabela **espelha**
`src/data/attributes.js`: ao mudar uma perícia, mudar os dois e rodar
`node supabase/tests/parity_skills.js`. **Ordem: publicar o `index.html` da Etapa 5
primeiro, aplicar a migração depois.** O cliente novo funciona com o banco antigo (que
só não valida o par); já o cliente antigo usa como padrão a perícia inexistente
`analise`, que o banco novo recusa.

`migration_player_projection.sql` só substitui duas funções (`player_get_session` e
`player_get_lobby`): não altera tabela, policy nem grant. O cliente publicado funciona
**antes e depois** dela — sem a migração, a filtragem de estresse e a limpeza do ferimento
acontecem só no navegador; com ela, acontecem no banco. Então, diferente do Ponto 2, aqui
a ordem entre deploy e migração é livre.

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

Atalho (a partir da raiz do repositório, com Docker rodando):

```bash
bash supabase/tests/run_all.sh
```

Ou manualmente:

```bash
for suite in ponto1_tests ponto2_tests ponto2b_tests ponto3_tests; do
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

Esperado: **52** no Ponto 1, **73** no Ponto 2, **24** no 2B (relógios/estresse) e
**32** no Ponto 3.

Cada arquivo cria o schema `t`, então **cada suíte precisa de uma base recém-criada** — rodar duas na mesma base falha na segunda. Recriar o container entre elas.

Os testes das etapas anteriores são a regressão e precisam continuar passando: ao aplicar
`migration_player_projection.sql`, `ponto1_tests` e `ponto2_tests` seguem verdes.
