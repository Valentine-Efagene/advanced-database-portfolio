#!/usr/bin/env bash
# Portfolio 3: two concurrent payouts from the same wallet, serialised by SELECT ... FOR UPDATE.
# Session A locks wallet 1 and holds the lock for 10 seconds; session B tries to lock the same
# row and must wait; an observer session captures the wait from pg_stat_activity.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$ROOT/portfolio-5-distributed-cloud/Efagene_Valentine_301921385_P5_DockerCompose.yml"
SERVICE="${VALPAY_PG_SERVICE:-postgres-primary}"
OUT_DIR="$ROOT/portfolio-3-transactions-concurrency/evidence/script-output"
OUT="$OUT_DIR/Efagene_Valentine_301921385_P3_ConcurrencyDemo.txt"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT_DIR"

psql_session() {
  local app="$1"
  shift
  docker compose -f "$COMPOSE_FILE" exec -T -e PGPASSWORD=valpay_dev -e PGAPPNAME="$app" "$SERVICE" \
    psql -v ON_ERROR_STOP=1 -X -q -P border=2 -U valpay -d valpay "$@"
}

psql_session setup > "$TMP/before.txt" <<'SQL'
SELECT account_number, balance AS balance_before FROM wallet_account WHERE account_id = 1;
SQL

psql_session session_a > "$TMP/a.txt" 2>&1 <<'SQL' &
\echo '[A] BEGIN'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS a_lock_acquired_at,
       balance AS a_reads_balance
FROM wallet_account WHERE account_id = 1 FOR UPDATE;
\echo '[A] holding row lock on wallet 1 for 10 seconds (simulated payout processing)'
SELECT pg_sleep(10);
UPDATE wallet_account SET balance = balance - 1000.00 WHERE account_id = 1;
COMMIT;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS a_committed_at;
\echo '[A] COMMIT: debited 1,000.00'
SQL
PID_A=$!

# Container exec start-up is slow and variable, so wait on database state rather than wall-clock sleeps.
wait_for() {
  local sql="$1"
  for _ in $(seq 1 60); do
    if [[ "$(psql_session poller -t -A -c "$sql" </dev/null 2>/dev/null | tr -d '[:space:]')" == "1" ]]; then
      return 0
    fi
    sleep 0.25
  done
  echo "Timed out waiting for: $sql" >&2
  exit 1
}

wait_for "SELECT count(*) FROM pg_stat_activity WHERE application_name = 'session_a' AND wait_event = 'PgSleep'"

psql_session session_b > "$TMP/b.txt" 2>&1 <<'SQL' &
\echo '[B] BEGIN'
BEGIN;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_requested_lock_at;
SELECT to_char(clock_timestamp(), 'HH24:MI:SS.MS') AS b_lock_acquired_at,
       balance AS b_reads_balance
FROM wallet_account WHERE account_id = 1 FOR UPDATE;
UPDATE wallet_account SET balance = balance - 500.00 WHERE account_id = 1;
COMMIT;
\echo '[B] COMMIT: debited 500.00'
SQL
PID_B=$!

wait_for "SELECT count(*) FROM pg_stat_activity WHERE application_name = 'session_b' AND wait_event_type = 'Lock'"

psql_session observer > "$TMP/observer.txt" <<'SQL'
\echo 'Observer (taken while session B is blocked):'
SELECT application_name AS session,
       state,
       wait_event_type,
       wait_event,
       pg_blocking_pids(pid) AS blocked_by_pid,
       left(query, 60) AS current_query
FROM pg_stat_activity
WHERE application_name IN ('session_a', 'session_b')
ORDER BY application_name;
SQL

wait "$PID_A" "$PID_B"

psql_session setup > "$TMP/after.txt" <<'SQL'
SELECT account_number, balance AS balance_after FROM wallet_account WHERE account_id = 1;
SQL

{
  echo "=== Portfolio 3: concurrent payouts on wallet 1 with SELECT ... FOR UPDATE ==="
  echo
  cat "$TMP/before.txt"
  echo "--- Session A ---"
  cat "$TMP/a.txt"
  echo
  echo "--- Session B (started after A acquired the row lock) ---"
  cat "$TMP/b.txt"
  echo
  echo "--- Observer ---"
  cat "$TMP/observer.txt"
  echo
  cat "$TMP/after.txt"
  echo "Expected: balance_after = balance_before - 1,000.00 - 500.00 (no lost update)."
} > "$OUT"

cat "$OUT"
