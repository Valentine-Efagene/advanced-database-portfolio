# MIT 8103 — Advanced Database Systems Portfolio (ValPay fintech)

**Student:** Valentine Efagene  
**LMS upload folder:** `Efagene_Valentine_<StudentID>` — see [submission/README.md](./submission/README.md)

**Case study:** [ValPay](./CASE_STUDY.md) — wallet, P2P transfers, ledger (replace brand name with your live product if different).

```bash
cd advanced-database-portfolio
./scripts/init_and_evidence.sh
```

Creates `data/valpay.db` and refreshes `portfolio-*/evidence/` text outputs.

| Folder | Focus |
|--------|--------|
| portfolio-1-database-design | ER, schema, normalisation |
| portfolio-2-query-optimisation | SQL + EXPLAIN |
| portfolio-3-transactions-concurrency | P2P transfer ACID |
| portfolio-4-nosql | KYC + activity events (MongoDB) |
| portfolio-5-distributed-cloud | Cloud HA / CAP for fintech |
| submission | LMS-named folder + CA PDF (run `apply_lms_naming.sh`) |

Push to a **private** GitHub repo. Build `Efagene_Valentine_<StudentID>/` and submit via [CA form](https://lms.miva.university/mod/page/view.php?id=166107) (**one attempt**).
