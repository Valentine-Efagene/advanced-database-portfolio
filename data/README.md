# Local database (not committed)

Relational evidence uses **PostgreSQL 16** via Docker:

```bash
./scripts/init_and_evidence.sh
```

Connection (matches `portfolio-5-distributed-cloud/docker-compose.yml`):

`postgresql://valpay:valpay_dev@localhost:5432/valpay`

Legacy SQLite files (`*.db`) are ignored if present.
