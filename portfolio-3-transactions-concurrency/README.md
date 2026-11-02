# Portfolio 3 — Transactions (ValPay)

P2P transfer implemented with `BEGIN IMMEDIATE` / `COMMIT` / `ROLLBACK`:

- Failed transfer when debit would exceed balance (no row persisted)
- Successful transfer updates both wallets, ledger postings, audit row

SQLite serializable isolation; production ValPay would use PostgreSQL row locks on `wallet_account`.
