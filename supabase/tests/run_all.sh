#!/usr/bin/env bash
# Roda todas as suítes SQL, cada uma numa base recém-criada (Postgres 15 em Docker).
# Uso: bash supabase/tests/run_all.sh   (a partir da raiz do repositório)
set -u
export MSYS_NO_PATHCONV=1
cd "$(dirname "$0")/.."
ALL="tests/.all_migrations.tmp.sql"
cat tests/00_stub_supabase.sql schema.sql migration_invite_code.sql \
    migration_table_members.sql migration_session_state.sql \
    migration_rls_hardening.sql migration_leave_table.sql \
    migration_archive_table.sql migration_profiles.sql \
    migration_requests_consequences.sql migration_rls_p2.sql \
    migration_player_projection.sql migration_session_persistence.sql \
    migration_skill_pairs.sql migration_identity.sql migration_equipment_photo.sql migration_scenes.sql migration_clocks_stress.sql > "$ALL"
fail=0
for suite in ponto1_tests ponto2_tests ponto2b_tests ponto3_tests ponto5_tests pos0_tests pos1_tests pos2_tests pos3_tests; do
  docker rm -f adpg >/dev/null 2>&1
  docker run -d --name adpg -e POSTGRES_PASSWORD=pg postgres:15 >/dev/null
  until docker exec adpg pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
  sleep 1
  docker cp "$ALL" adpg:/tmp/all.sql
  docker cp "tests/$suite.sql" adpg:/tmp/t.sql
  docker cp migration_identity.sql adpg:/tmp/mig.sql
  docker exec adpg psql -U postgres -v ON_ERROR_STOP=1 -q -f /tmp/all.sql >/dev/null 2>/tmp/adpg_mig.err || { echo "== $suite: MIGRAÇÃO FALHOU"; cat /tmp/adpg_mig.err; fail=1; continue; }
  out="$(docker exec adpg psql -U postgres -q -f /tmp/t.sql 2>&1)"
  echo "== $suite: $(echo "$out" | grep -cE 'PASSOU') PASSOU"
  echo "$out" | grep -E "FALHOU|ERROR|TODOS" || true
  echo "$out" | grep -qE "FALHOU|ERROR" && fail=1
done
docker rm -f adpg >/dev/null 2>&1
rm -f "$ALL"
# paridade catalogo do app x tabela do banco (atributo/pericia)
echo "== paridade:"; node tests/parity_skills.js || fail=1
exit $fail
