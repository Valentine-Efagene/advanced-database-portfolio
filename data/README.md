# Local database (not committed)

Relational evidence uses **PostgreSQL 16** via Docker:

```bash
./scripts/Efagene_Valentine_301921385_InitAndEvidence.sh
```

Connection (matches `portfolio-5-distributed-cloud/Efagene_Valentine_301921385_P5_DockerCompose.yml`):

`postgresql://valpay:valpay_dev@localhost:5432/valpay`

Legacy SQLite files (`*.db`) are ignored if present.
