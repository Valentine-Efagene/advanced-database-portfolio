# Portfolio 1 — Database design (ValPay fintech)

- [er-diagram.mmd](./er-diagram.mmd) — ER model (customer, wallet, ledger, transfer)
- [schema.sql](./schema.sql) — DDL and indexes
- [NORMALIZATION.md](./NORMALIZATION.md)
- [evidence/schema_dump.txt](./evidence/schema_dump.txt) — run root script

```bash
sqlite3 ../data/valpay.db < schema.sql
```

Or `./scripts/init_and_evidence.sh` from repository root.
