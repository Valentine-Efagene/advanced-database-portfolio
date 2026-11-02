# Portfolio 4 — NoSQL (ValPay)

Fintech workloads often split **ledger OLTP** (relational, Portfolio 1–3) from **semi-structured operational data**:

| Collection | Purpose |
|------------|---------|
| `kyc_documents` | Tier upgrades, ID metadata, verification status |
| `fraud_signals` | Rule hits, device fingerprint summaries |
| `activity_events` | Login, transfer initiated, OTP sent (high volume) |

## Files

- [kyc_schema.json](./kyc_schema.json)
- [sample_kyc.jsonl](./sample_kyc.jsonl)
- [sample_activity.jsonl](./sample_activity.jsonl)
- [queries.mongodb.js](./queries.mongodb.js)
- [SUITABILITY.md](./SUITABILITY.md)

Optional: `docker run -p 27017:27017 mongo:7` then `mongosh valpay --file queries.mongodb.js`
