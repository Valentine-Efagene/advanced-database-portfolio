# Portfolio 5 — Distributed and cloud (ValPay)

Production fintech architecture emphasises **strong consistency** on the ledger, **high availability**, and **regulatory auditability**.

```
 [ Mobile app / API ]
         |
   [ API gateway + WAF ]
         |
 +-------+--------+
 |                |
[RDS PostgreSQL   [ MongoDB Atlas ]
 Primary]         KYC + activity events
 |  synchronous
 Read replica(s) — statements, BI
 |
[ Redis ] — idempotency keys, rate limits
```

## CAP for payments

- **Ledger writes:** CP — single primary, synchronous replication (Multi-AZ).
- **Activity feed reads:** can use secondary with eventual consistency for dashboards.

## Sharding path

- Shard `activity_events` by `customer_id` when event volume grows.
- Keep ledger on a single highly tuned cluster until vertical scale limits; then consider partitioning `ledger_posting` by month.

## Compliance

- Encrypt at rest (RDS/KMS, Atlas encryption).
- Immutable audit (`transaction_audit` + append-only object storage for raw logs).
- NDPA: TTL on Mongo event collections; PII minimisation in `metadata.masked_id`.

## Local demo

[Efagene_Valentine_301921385_P5_DockerCompose.yml](./Efagene_Valentine_301921385_P5_DockerCompose.yml) — PostgreSQL (ledger) + MongoDB (Portfolios 1–4 evidence and NoSQL).

Regenerate SQL evidence:

```bash
./scripts/Efagene_Valentine_301921385_InitAndEvidence.sh
```

See [evidence/Efagene_Valentine_301921385_P5_ConnectionNotes.txt](./evidence/Efagene_Valentine_301921385_P5_ConnectionNotes.txt).
