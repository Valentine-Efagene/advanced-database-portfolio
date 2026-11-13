# Portfolio 4 — NoSQL (ValPay)

Fintech workloads often split **ledger OLTP** (relational, Portfolio 1–3) from **semi-structured operational data**:

| Collection | Purpose |
|------------|---------|
| `kyc_documents` | Tier upgrades, ID metadata, verification status |
| `fraud_signals` | Rule hits, device fingerprint summaries |
| `activity_events` | Login, transfer initiated, OTP sent (high volume) |

## Files

- [Efagene_Valentine_301921385_P4_KYCSchema.json](./Efagene_Valentine_301921385_P4_KYCSchema.json)
- [Efagene_Valentine_301921385_P4_SampleKYC.jsonl](./Efagene_Valentine_301921385_P4_SampleKYC.jsonl)
- [Efagene_Valentine_301921385_P4_SampleActivity.jsonl](./Efagene_Valentine_301921385_P4_SampleActivity.jsonl)
- [Efagene_Valentine_301921385_P4_Queries.mongodb.js](./Efagene_Valentine_301921385_P4_Queries.mongodb.js)
- [Efagene_Valentine_301921385_P4_SUITABILITY.md](./Efagene_Valentine_301921385_P4_SUITABILITY.md)

Optional: `docker run -p 27017:27017 mongo:7` then `mongosh valpay --file Efagene_Valentine_301921385_P4_Queries.mongodb.js`
