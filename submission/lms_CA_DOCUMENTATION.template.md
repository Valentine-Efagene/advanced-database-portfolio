# MIT 8103 Continuous Assessment — Portfolio Documentation

**Course:** MIT 8103 Advanced Database Systems  
**Student:** {{FIRSTNAME}} {{SURNAME}}  
**MIVA Student ID:** {{STUDENT_ID}}  
**GitHub:** *(private repo URL — same as in {{SURNAME}}_{{FIRSTNAME}}_{{STUDENT_ID}}_README.txt)*  
**Case study:** **ValPay** — mobile wallet / payments fintech

---

## 1. Case study statement

ValPay provides digital wallets in NGN, P2P transfers, top-ups, and auditable transaction history. Users are retail customers; internal users include compliance, finance, and support. Data includes customers, wallet accounts, double-entry ledger postings, transfers, beneficiaries, and audit events. Operations include balance-checked transfers, idempotent payment APIs, reversals, statements, and fraud monitoring (with MongoDB event data in Portfolio 4).

---

## 2. Portfolio summary

| # | Activity | Evidence |
|---|----------|----------|
| 1 | ER model, relational schema, normalisation | GitHub `portfolio-1-database-design/`; LMS file `{{SURNAME}}_{{FIRSTNAME}}_{{STUDENT_ID}}_SCHEMA_EVIDENCE.txt` |
| 2 | SQL queries, indexing, EXPLAIN plans | `portfolio-2-query-optimisation/`; `_QUERY_EVIDENCE.txt`, `_EXPLAIN_EVIDENCE.txt` |
| 3 | P2P transfer commit/rollback | `portfolio-3-transactions-concurrency/`; `_TRANSACTION_EVIDENCE.txt` |
| 4 | KYC + activity events (MongoDB) | `portfolio-4-nosql/` |
| 5 | Cloud HA / CAP for fintech | `portfolio-5-distributed-cloud/` |

**LMS submission folder name:** `{{SURNAME}}_{{FIRSTNAME}}_{{STUDENT_ID}}`  
**File naming:** `{{SURNAME}}_{{FIRSTNAME}}_{{STUDENT_ID}}_<DocumentType>` (see [CA page](https://lms.miva.university/mod/page/view.php?id=166107)).

---

## 3. Technical reflection

Using a **ledger + wallet balance** model mirrors real fintech constraints: balances must match controlled debits/credits. SQLite demonstrates the same transaction patterns as PostgreSQL for production ValPay. NoSQL stores KYC and behavioural events without weakening ledger ACID. The main lesson is **polyglot persistence** with strict boundaries—money stays relational; analytics stays document/event oriented.

---

## 4. References

- Miva Open University. (2026). *MIT 8103 CA brief — September cohort 2026*.
- SQLite Project. *SQLite documentation*. https://www.sqlite.org/docs.html
- MongoDB Inc. *MongoDB manual*. https://www.mongodb.com/docs/

---

## 5. AI use declaration

Cursor AI assisted with schema design, SQL/Mongo samples, and documentation drafting. All SQL was executed via `scripts/init_and_evidence.sh`; outputs are in `evidence/` folders and copied into LMS-named files by `submission/apply_lms_naming.sh`. I, {{FIRSTNAME}} {{SURNAME}}, verified balances, rollback behaviour, and query results before submission.

---

## 6. Checklist

- [ ] Folder `{{SURNAME}}_{{FIRSTNAME}}_{{STUDENT_ID}}` with correctly prefixed files  
- [ ] Private GitHub + assessor access  
- [ ] PDF: `{{SURNAME}}_{{FIRSTNAME}}_{{STUDENT_ID}}_CA_DOCUMENTATION.pdf`  
- [ ] Google Form submitted once  
- [ ] Similarity under 20% (excluding bibliography)
