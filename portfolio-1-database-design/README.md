# Portfolio 1 — Database design (ValPay)

- [Efagene_Valentine_301921385_P1_ERDiagram.mmd](./Efagene_Valentine_301921385_P1_ERDiagram.mmd) — ER model (Mermaid)
- [Efagene_Valentine_301921385_P1_Schema.sql](./Efagene_Valentine_301921385_P1_Schema.sql) — PostgreSQL DDL
- [Efagene_Valentine_301921385_P1_NORMALIZATION.md](./Efagene_Valentine_301921385_P1_NORMALIZATION.md) — 1NF–3NF notes
- [evidence/script-output/Efagene_Valentine_301921385_P1_SchemaDump.txt](./evidence/script-output/Efagene_Valentine_301921385_P1_SchemaDump.txt) — `pg_dump --schema-only`

Apply schema locally:

```bash
./scripts/Efagene_Valentine_301921385_InitAndEvidence.sh
```

Or manually after PostgreSQL is running:

```bash
psql postgresql://valpay:valpay_dev@localhost:5432/valpay -f Efagene_Valentine_301921385_P1_Schema.sql
```
