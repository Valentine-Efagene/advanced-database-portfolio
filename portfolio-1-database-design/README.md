# Portfolio 1 — Database design (ValPay)

- [er-diagram.mmd](./er-diagram.mmd) — ER model (Mermaid)
- [schema.sql](./schema.sql) — PostgreSQL DDL
- [NORMALIZATION.md](./NORMALIZATION.md) — 1NF–3NF notes
- [evidence/schema_dump.txt](./evidence/schema_dump.txt) — `pg_dump --schema-only`

Apply schema locally:

```bash
./scripts/init_and_evidence.sh
```

Or manually after PostgreSQL is running:

```bash
psql postgresql://valpay:valpay_dev@localhost:5432/valpay -f schema.sql
```
