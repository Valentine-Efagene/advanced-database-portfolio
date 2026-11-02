#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="$ROOT/data/valpay.db"
mkdir -p "$ROOT/data"
rm -f "$DB" "$ROOT/data/"*.db "$ROOT/data/"*.db-journal

echo "Creating database at $DB"
sqlite3 "$DB" < "$ROOT/portfolio-1-database-design/schema.sql"
sqlite3 "$DB" < "$ROOT/scripts/seed.sql"

mkdir -p "$ROOT/portfolio-1-database-design/evidence"
sqlite3 "$DB" ".schema" > "$ROOT/portfolio-1-database-design/evidence/schema_dump.txt"

mkdir -p "$ROOT/portfolio-2-query-optimisation/evidence"
sqlite3 "$DB" < "$ROOT/portfolio-2-query-optimisation/queries.sql" \
  > "$ROOT/portfolio-2-query-optimisation/evidence/query_results.txt" 2>&1

{
  echo "=== EXPLAIN Q3 BEFORE ==="
  sqlite3 "$DB" "DROP INDEX IF EXISTS idx_transaction_reference;"
  sqlite3 "$DB" "EXPLAIN QUERY PLAN SELECT transaction_id FROM wallet_transaction WHERE reference LIKE 'VP-TXN-202610%';"
  echo "=== EXPLAIN Q3 AFTER ==="
  sqlite3 "$DB" "CREATE INDEX IF NOT EXISTS idx_transaction_reference ON wallet_transaction(reference);"
  sqlite3 "$DB" "EXPLAIN QUERY PLAN SELECT transaction_id FROM wallet_transaction WHERE reference LIKE 'VP-TXN-202610%';"
} > "$ROOT/portfolio-2-query-optimisation/evidence/explain_plans.txt"

mkdir -p "$ROOT/portfolio-3-transactions-concurrency/evidence"
sqlite3 "$DB" < "$ROOT/portfolio-3-transactions-concurrency/transactions.sql" \
  > "$ROOT/portfolio-3-transactions-concurrency/evidence/transaction_run.txt" 2>&1

echo "Done. ValPay portfolio evidence updated."
