#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/portfolio-5-distributed-cloud/Efagene_Valentine_301921385_P5_DockerCompose.yml"
SERVICE="${VALPAY_PG_SERVICE:-postgres-primary}"

export PGUSER="${PGUSER:-valpay}"
export PGPASSWORD="${PGPASSWORD:-valpay_dev}"
export PGDATABASE="${PGDATABASE:-valpay}"

psql_in_container() {
  docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD="$PGPASSWORD" "$SERVICE" \
    psql -v ON_ERROR_STOP=1 -U "$PGUSER" -d "$PGDATABASE" "$@"
}

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required to start PostgreSQL via compose."
  exit 1
fi

echo "Starting PostgreSQL (docker compose)..."
docker compose -f "$COMPOSE_FILE" up -d "$SERVICE"

echo "Waiting for PostgreSQL..."
for _ in $(seq 1 60); do
  if docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
      pg_isready -U "$PGUSER" -d "$PGDATABASE" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! docker compose -f "$COMPOSE_FILE" exec -T "$SERVICE" \
    pg_isready -U "$PGUSER" -d "$PGDATABASE" >/dev/null 2>&1; then
  echo "PostgreSQL did not become ready in time."
  exit 1
fi

echo "Resetting schema in database: $PGDATABASE"
psql_in_container <<'SQL'
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO valpay;
GRANT ALL ON SCHEMA public TO public;
SQL

psql_in_container -f - < "$ROOT/portfolio-1-database-design/Efagene_Valentine_301921385_P1_Schema.sql"
psql_in_container -f - < "$ROOT/scripts/Efagene_Valentine_301921385_Seed.sql"

mkdir -p "$ROOT/portfolio-1-database-design/evidence/script-output"
docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD="$PGPASSWORD" "$SERVICE" \
  pg_dump --schema-only --no-owner --no-privileges -U "$PGUSER" "$PGDATABASE" \
  > "$ROOT/portfolio-1-database-design/evidence/script-output/Efagene_Valentine_301921385_P1_SchemaDump.txt"

mkdir -p "$ROOT/portfolio-2-query-optimisation/evidence/script-output"
psql_in_container -f - < "$ROOT/portfolio-2-query-optimisation/Efagene_Valentine_301921385_P2_Queries.sql" \
  > "$ROOT/portfolio-2-query-optimisation/evidence/script-output/Efagene_Valentine_301921385_P2_QueryResults.txt" 2>&1

# Efagene_Valentine_301921385_P2_Optimisation.sql drops idx_transaction_reference, runs EXPLAIN on Q3, recreates
# the index (text_pattern_ops) and runs EXPLAIN again, plus the Q1 join plan.
psql_in_container -f - < "$ROOT/portfolio-2-query-optimisation/Efagene_Valentine_301921385_P2_Optimisation.sql" \
  > "$ROOT/portfolio-2-query-optimisation/evidence/script-output/Efagene_Valentine_301921385_P2_ExplainPlans.txt" 2>&1

mkdir -p "$ROOT/portfolio-3-transactions-concurrency/evidence/script-output"
psql_in_container -f - < "$ROOT/portfolio-3-transactions-concurrency/Efagene_Valentine_301921385_P3_Transactions.sql" \
  > "$ROOT/portfolio-3-transactions-concurrency/evidence/script-output/Efagene_Valentine_301921385_P3_TransactionRun.txt" 2>&1

echo "Done. ValPay portfolio evidence updated (PostgreSQL): outputs in portfolio-*/evidence/script-output/."
