# Portfolio 3 — Transactions (ValPay)

P2P transfer implemented with `BEGIN` / `COMMIT` / `ROLLBACK` on PostgreSQL:

- Failed transfer when debit would exceed balance (no row persisted after rollback)
- Successful transfer updates both wallets, ledger postings, audit row

Uses standard MVCC transactions; production ValPay would add `SELECT … FOR UPDATE` on `wallet_account` rows under concurrent API load.

Run: `./scripts/init_and_evidence.sh` → [evidence/transaction_run.txt](./evidence/transaction_run.txt)
