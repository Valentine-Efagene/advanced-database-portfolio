# MIT 8103 — Advanced Database Systems Portfolio

**Student:** Valentine Efagene · **MIVA ID:** 301921385  
**Case study:** [ValPay](./Efagene_Valentine_301921385_CASE_STUDY.md) — fintech wallet and P2P transfers  

Public repository for assessor review (no access request required).

## Structure

| Path | Portfolio |
|------|-----------|
| [portfolio-1-database-design](./portfolio-1-database-design/) | ER model, schema, normalisation |
| [portfolio-2-query-optimisation](./portfolio-2-query-optimisation/) | SQL, indexing, EXPLAIN plans |
| [portfolio-3-transactions-concurrency](./portfolio-3-transactions-concurrency/) | ACID transfers (commit / rollback) |
| [portfolio-4-nosql](./portfolio-4-nosql/) | MongoDB KYC and activity events |
| [portfolio-5-distributed-cloud](./portfolio-5-distributed-cloud/) | Cloud HA, CAP, deployment notes |
| [Efagene_Valentine_301921385_DOCUMENTATION.md](./Efagene_Valentine_301921385_DOCUMENTATION.md) | Summary, reflection, references |

## Regenerate evidence

```bash
./scripts/Efagene_Valentine_301921385_InitAndEvidence.sh
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
Efagene_Valentine_301921385_DOCUMENTATION.md
scripts/
```
