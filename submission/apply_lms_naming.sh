#!/usr/bin/env bash
# Build LMS upload folder per CA page (Surname_Firstname_StudentID)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY="$ROOT/submission/student.identity"

if [[ ! -f "$IDENTITY" ]]; then
  echo "Missing $IDENTITY"
  exit 1
fi

# shellcheck disable=SC1090
source "$IDENTITY"

if [[ -n "${1:-}" ]]; then
  STUDENT_ID="$1"
fi

if [[ -z "${SURNAME:-}" || -z "${FIRSTNAME:-}" || -z "${STUDENT_ID:-}" ]]; then
  echo "Set SURNAME, FIRSTNAME, and STUDENT_ID in submission/student.identity"
  echo "Or run: ./submission/apply_lms_naming.sh YOUR_STUDENT_ID"
  exit 1
fi

PREFIX="${SURNAME}_${FIRSTNAME}_${STUDENT_ID}"
OUT="$ROOT/submission/${PREFIX}"
mkdir -p "$OUT"

DOC_SRC="$ROOT/submission/lms_CA_DOCUMENTATION.template.md"
if [[ ! -f "$DOC_SRC" ]]; then
  echo "Missing template: $DOC_SRC"
  exit 1
fi

sed \
  -e "s/{{SURNAME}}/$SURNAME/g" \
  -e "s/{{FIRSTNAME}}/$FIRSTNAME/g" \
  -e "s/{{STUDENT_ID}}/$STUDENT_ID/g" \
  -e "s/{{FULL_NAME}}/$SURNAME $FIRSTNAME/g" \
  "$DOC_SRC" > "$OUT/${PREFIX}_CA_DOCUMENTATION.md"

cat > "$OUT/${PREFIX}_README.txt" <<EOF
MIT 8103 Advanced Database Systems — Continuous Assessment
Student: ${FIRSTNAME} ${SURNAME}
MIVA Student ID: ${STUDENT_ID}

Case study: ValPay (fintech wallet / P2P transfers)

GitHub repository (private — grant assessor access):
PASTE_YOUR_GITHUB_URL_HERE

Contents of this folder:
- ${PREFIX}_CA_DOCUMENTATION.md — export to PDF before form upload
- ${PREFIX}_SCHEMA_EVIDENCE.txt — Portfolio 1 schema dump
- ${PREFIX}_QUERY_EVIDENCE.txt — Portfolio 2 query output
- ${PREFIX}_EXPLAIN_EVIDENCE.txt — Portfolio 2 EXPLAIN plans
- ${PREFIX}_TRANSACTION_EVIDENCE.txt — Portfolio 3 ACID demo output

Regenerate evidence: from repo root run ./scripts/init_and_evidence.sh then re-run ./submission/apply_lms_naming.sh

LMS form: https://docs.google.com/forms/d/e/1FAIpQLSezIt3hWMbx0MpN6ynp9wBXqq5unzc5DiXD3tQKPzkA3CNIeg/viewform
CA instructions: https://lms.miva.university/mod/page/view.php?id=166107

Naming rules: no spaces; do not use generic names like Assignment or Final File.
EOF

cp "$ROOT/portfolio-1-database-design/evidence/schema_dump.txt" \
  "$OUT/${PREFIX}_SCHEMA_EVIDENCE.txt"
cp "$ROOT/portfolio-2-query-optimisation/evidence/query_results.txt" \
  "$OUT/${PREFIX}_QUERY_EVIDENCE.txt"
cp "$ROOT/portfolio-2-query-optimisation/evidence/explain_plans.txt" \
  "$OUT/${PREFIX}_EXPLAIN_EVIDENCE.txt"
cp "$ROOT/portfolio-3-transactions-concurrency/evidence/transaction_run.txt" \
  "$OUT/${PREFIX}_TRANSACTION_EVIDENCE.txt"

echo "Created: $OUT"
echo "Next:"
echo "  1. Edit ${PREFIX}_README.txt — add GitHub URL"
echo "  2. Export ${PREFIX}_CA_DOCUMENTATION.md to PDF (keep same base name + .pdf)"
echo "  3. Upload folder/files via Google Form (one attempt)"
