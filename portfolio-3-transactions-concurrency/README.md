# Portfolio 3 — Transactions (ValPay)

P2P transfer implemented with `BEGIN` / `COMMIT` / `ROLLBACK` on PostgreSQL:

- Failed transfer when debit would exceed balance (no row persisted after rollback)
- Successful transfer updates both wallets, ledger postings, audit row

Run: `./scripts/Efagene_Valentine_301921385_InitAndEvidence.sh` → [evidence/script-output/Efagene_Valentine_301921385_P3_TransactionRun.txt](./evidence/script-output/Efagene_Valentine_301921385_P3_TransactionRun.txt)

## Concurrency control: row locking

[Efagene_Valentine_301921385_P3_ConcurrencyDemo.sh](./Efagene_Valentine_301921385_P3_ConcurrencyDemo.sh) runs two payouts against the same wallet at the same time:

- Session A takes `SELECT … FOR UPDATE` on wallet 1 and holds it for 10 seconds before debiting 1,000.
- Session B requests the same row lock and waits (`wait_event_type = Lock`, blocked by A's PID).
- When A commits, B acquires the lock, reads A's committed balance and debits 500.
- The final balance equals the starting balance minus both debits, so there is no lost update.

Output: [evidence/script-output/Efagene_Valentine_301921385_P3_ConcurrencyDemo.txt](./evidence/script-output/Efagene_Valentine_301921385_P3_ConcurrencyDemo.txt) and [Screenshot05](./evidence/screenshots/Efagene_Valentine_301921385_P3_Screenshot05_ConcurrencyRowLock.png).
