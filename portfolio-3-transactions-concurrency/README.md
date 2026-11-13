# Portfolio 3 — Transactions (ValPay)

P2P transfer implemented with `BEGIN` / `COMMIT` / `ROLLBACK` on PostgreSQL:

- Failed transfer when debit would exceed balance (no row persisted after rollback)
- Successful transfer updates both wallets, ledger postings, audit row

Uses standard MVCC transactions; production ValPay would add `SELECT … FOR UPDATE` on `wallet_account` rows under concurrent API load.

Run: `./scripts/Efagene_Valentine_301921385_InitAndEvidence.sh` → [evidence/script-output/Efagene_Valentine_301921385_P3_TransactionRun.txt](./evidence/script-output/Efagene_Valentine_301921385_P3_TransactionRun.txt)
