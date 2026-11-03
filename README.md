# MIT 8103 — Advanced Database Systems Portfolio

**Student:** Valentine Efagene · **MIVA ID:** 301921385  
**Case study:** [ValPay](./CASE_STUDY.md) — fintech wallet and P2P transfers  

Private repository for assessors: grant read access before marking.

## Structure

| Path | Portfolio |
|------|-----------|
| [portfolio-1-database-design](./portfolio-1-database-design/) | ER model, schema, normalisation |
| [portfolio-2-query-optimisation](./portfolio-2-query-optimisation/) | SQL, indexing, EXPLAIN plans |
| [portfolio-3-transactions-concurrency](./portfolio-3-transactions-concurrency/) | ACID transfers (commit / rollback) |
| [portfolio-4-nosql](./portfolio-4-nosql/) | MongoDB KYC and activity events |
| [portfolio-5-distributed-cloud](./portfolio-5-distributed-cloud/) | Cloud HA, CAP, deployment notes |
| [DOCUMENTATION.md](./DOCUMENTATION.md) | Summary, reflection, references |

## Regenerate evidence

```bash
./scripts/init_and_evidence.sh
```

Starts PostgreSQL via Docker, loads schema/seed, and refreshes `portfolio-*/evidence/*.txt`.

**Requires:** Docker, `psql`, and `pg_dump` (PostgreSQL client tools).

## Suggested repo layout (CA brief)

```
portfolio-1-database-design/
portfolio-2-query-optimisation/
portfolio-3-transactions-concurrency/
portfolio-4-nosql/
portfolio-5-distributed-cloud/
README.md
DOCUMENTATION.md
scripts/
```
