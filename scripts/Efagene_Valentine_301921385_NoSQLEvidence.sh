#!/usr/bin/env bash
# Portfolio 4 (MongoDB): load the seed, run the queries and write evidence.
#
#   scripts/Efagene_Valentine_301921385_NoSQLEvidence.sh            # uses the mongo service in portfolio-5-distributed-cloud/Efagene_Valentine_301921385_P5_DockerCompose.yml
#   MONGO_MODE=local scripts/Efagene_Valentine_301921385_NoSQLEvidence.sh   # uses a local mongosh and MONGO_URI (default mongodb://localhost:27017)
#
# Writes portfolio-4-nosql/evidence/script-output/*.txt and refreshes the two sample .jsonl files.
# If the PostgreSQL service is running (scripts/Efagene_Valentine_301921385_InitAndEvidence.sh), it also
# cross-checks the MongoDB events and KYC tiers against the relational data.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P4="$ROOT/portfolio-4-nosql"
EVIDENCE="$P4/evidence/script-output"
COMPOSE_FILE="$ROOT/portfolio-5-distributed-cloud/Efagene_Valentine_301921385_P5_DockerCompose.yml"
MONGO_MODE="${MONGO_MODE:-docker}"
MONGO_SERVICE="${VALPAY_MONGO_SERVICE:-mongo}"
MONGO_URI="${MONGO_URI:-mongodb://localhost:27017}"
PG_SERVICE="${VALPAY_PG_SERVICE:-postgres-primary}"
export PGUSER="${PGUSER:-valpay}" PGPASSWORD="${PGPASSWORD:-valpay_dev}" PGDATABASE="${PGDATABASE:-valpay}"
WORKDIR=/tmp/valpay-p4

compose() { docker compose -f "$COMPOSE_FILE" "$@"; }

# run one of the .mongodb.js files from portfolio-4-nosql
mongo_file() {
  if [ "$MONGO_MODE" = local ]; then
    (cd "$P4" && mongosh --quiet "$MONGO_URI/valpay" --file "$1")
  else
    compose exec -T -w "$WORKDIR" "$MONGO_SERVICE" mongosh --quiet valpay --file "$1"
  fi
}
mongo_eval() {
  if [ "$MONGO_MODE" = local ]; then
    mongosh --quiet "$MONGO_URI/valpay" --eval "$1"
  else
    compose exec -T "$MONGO_SERVICE" mongosh --quiet valpay --eval "$1"
  fi
}

if [ "$MONGO_MODE" = local ]; then
  command -v mongosh >/dev/null 2>&1 || { echo "mongosh is required for MONGO_MODE=local."; exit 1; }
else
  command -v docker >/dev/null 2>&1 || { echo "docker is required to start MongoDB via compose."; exit 1; }
  echo "Starting MongoDB (docker compose)..."
  compose up -d "$MONGO_SERVICE"
fi

echo "Waiting for MongoDB..."
for _ in $(seq 1 60); do
  if mongo_eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1; then break; fi
  sleep 1
done
mongo_eval 'db.runCommand({ ping: 1 }).ok' >/dev/null 2>&1 || { echo "MongoDB did not become ready in time."; exit 1; }

if [ "$MONGO_MODE" != local ]; then
  # copy the scripts and Efagene_Valentine_301921385_P4_KYCSchema.json into the container
  compose exec -T "$MONGO_SERVICE" sh -c "rm -rf $WORKDIR && mkdir -p $WORKDIR"
  for f in Efagene_Valentine_301921385_P4_KYCSchema.json Efagene_Valentine_301921385_P4_Seed.mongodb.js Efagene_Valentine_301921385_P4_Queries.mongodb.js Efagene_Valentine_301921385_P4_Explain.mongodb.js Efagene_Valentine_301921385_P4_Validation.mongodb.js Efagene_Valentine_301921385_P4_Samples.mongodb.js; do
    compose cp "$P4/$f" "$MONGO_SERVICE:$WORKDIR/$f" >/dev/null 2>&1
  done
fi

mkdir -p "$EVIDENCE"
echo "Loading seed..."
mongo_file Efagene_Valentine_301921385_P4_Seed.mongodb.js       > "$EVIDENCE/Efagene_Valentine_301921385_P4_LoadSummary.txt" 2>&1
echo "Running queries..."
mongo_file Efagene_Valentine_301921385_P4_Queries.mongodb.js    > "$EVIDENCE/Efagene_Valentine_301921385_P4_QueryResults.txt" 2>&1
echo "Running explain before/after..."
mongo_file Efagene_Valentine_301921385_P4_Explain.mongodb.js    > "$EVIDENCE/Efagene_Valentine_301921385_P4_ExplainPlans.txt" 2>&1
echo "Running validation tests..."
mongo_file Efagene_Valentine_301921385_P4_Validation.mongodb.js > "$EVIDENCE/Efagene_Valentine_301921385_P4_ValidationRejection.txt" 2>&1

echo "Refreshing Efagene_Valentine_301921385_P4_SampleKYC.jsonl and Efagene_Valentine_301921385_P4_SampleActivity.jsonl..."
mongo_file Efagene_Valentine_301921385_P4_Samples.mongodb.js | awk -v dir="$P4" '
  /^##FILE / { out = dir "/" $2; printf "" > out; next }
  out != "" { print >> out }'

# ---- optional cross-store check against PostgreSQL -------------------------------
pg_available() {
  if [ "$MONGO_MODE" = local ]; then
    command -v psql >/dev/null 2>&1 && psql -h "${PGHOST:-localhost}" -Atc 'select 1' >/dev/null 2>&1
  else
    [ -n "$(compose ps --status running -q "$PG_SERVICE" 2>/dev/null)" ]
  fi
}
pg_query() {
  if [ "$MONGO_MODE" = local ]; then
    psql -h "${PGHOST:-localhost}" -v ON_ERROR_STOP=1 -At -c "$1"
  else
    compose exec -T -e PGPASSWORD="$PGPASSWORD" "$PG_SERVICE" psql -v ON_ERROR_STOP=1 -U "$PGUSER" -d "$PGDATABASE" -At -c "$1"
  fi
}

CHECK="$EVIDENCE/Efagene_Valentine_301921385_P4_CrossStoreCheck.txt"
if pg_available; then
  echo "Cross-checking against PostgreSQL..."
  TMP="$(mktemp -d)"
  mongo_eval 'db.activity_events.find({ event: "transfer_initiated" }, { _id: 0, reference: 1, amount_ngn: 1, account_number: 1, beneficiary: 1 })
                .forEach((d) => print([d.reference, d.amount_ngn.toFixed(2), d.account_number, d.beneficiary].join("|")))' \
    | sort > "$TMP/mongo_transfers"
  pg_query "SELECT t.reference, t.amount, fa.account_number, ta.account_number
            FROM wallet_transaction t
            JOIN transfer_detail d USING (transaction_id)
            JOIN wallet_account fa ON fa.account_id = d.from_account_id
            JOIN wallet_account ta ON ta.account_id = d.to_account_id
            WHERE t.txn_type = 'TRANSFER'" | sort > "$TMP/pg_transfers"
  mongo_eval 'db.kyc_documents.aggregate([
      { $match: { status: "VERIFIED" } },
      { $group: { _id: "$customer_id", docs: { $addToSet: "$document_type" } } },
      { $project: { tier: { $switch: { branches: [
          { case: { $setIsSubset: [["BVN", "NIN", "UTILITY_BILL"], "$docs"] }, then: "TIER3" },
          { case: { $setIsSubset: [["BVN", "NIN"], "$docs"] }, then: "TIER2" } ], default: "TIER1" } } } }
    ]).forEach((d) => print(d._id + "|" + d.tier))' | sort > "$TMP/mongo_tiers"
  pg_query "SELECT customer_id, kyc_tier FROM customer WHERE customer_id <> 3" | sort > "$TMP/pg_tiers"
  {
    echo "=== Cross-store check: MongoDB (valpay) against PostgreSQL (valpay) ==="
    echo ""
    echo "Transfers: transfer_initiated events vs wallet_transaction + transfer_detail"
    echo "  (reference | amount | from account | to account)"
    echo "  MongoDB events            : $(wc -l < "$TMP/mongo_transfers" | tr -d ' ')"
    echo "  PostgreSQL transfers      : $(wc -l < "$TMP/pg_transfers" | tr -d ' ')"
    echo "  identical in both         : $(comm -12 "$TMP/mongo_transfers" "$TMP/pg_transfers" | wc -l | tr -d ' ')"
    echo "  only in MongoDB           : $(comm -23 "$TMP/mongo_transfers" "$TMP/pg_transfers" | wc -l | tr -d ' ')"
    comm -23 "$TMP/mongo_transfers" "$TMP/pg_transfers" | sed 's/^/    /'
    echo "  only in PostgreSQL        : $(comm -13 "$TMP/mongo_transfers" "$TMP/pg_transfers" | wc -l | tr -d ' ')"
    comm -13 "$TMP/mongo_transfers" "$TMP/pg_transfers" | sed 's/^/    /'
    echo ""
    echo "KYC tiers: tier derived from VERIFIED kyc_documents vs customer.kyc_tier (ops wallet 3 excluded)"
    echo "  customers compared        : $(wc -l < "$TMP/pg_tiers" | tr -d ' ')"
    echo "  same tier                 : $(comm -12 "$TMP/mongo_tiers" "$TMP/pg_tiers" | wc -l | tr -d ' ')"
    echo "  different or missing      : $(comm -3 "$TMP/mongo_tiers" "$TMP/pg_tiers" | wc -l | tr -d ' ')"
    comm -3 "$TMP/mongo_tiers" "$TMP/pg_tiers" | sed 's/^/    /'
    echo ""
    echo "Sample: VP-TXN-OK-004 in both stores"
    echo "  MongoDB   : $(grep '^VP-TXN-OK-004|' "$TMP/mongo_transfers" || echo 'not found')"
    echo "  PostgreSQL: $(grep '^VP-TXN-OK-004|' "$TMP/pg_transfers" || echo 'not found (run scripts/Efagene_Valentine_301921385_InitAndEvidence.sh first)')"
  } > "$CHECK"
  rm -rf "$TMP"
else
  echo "PostgreSQL is not running; skipped Efagene_Valentine_301921385_P4_CrossStoreCheck.txt (run scripts/Efagene_Valentine_301921385_InitAndEvidence.sh first)."
fi

echo "Done. Portfolio 4 evidence written to portfolio-4-nosql/evidence/script-output/"
