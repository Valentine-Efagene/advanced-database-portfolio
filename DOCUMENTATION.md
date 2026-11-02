# Portfolio documentation

**Course:** MIT 8103 Advanced Database Systems  
**Student:** Valentine Efagene · **MIVA ID:** 301921385  
**Case study:** [ValPay](./CASE_STUDY.md)

## 1. Case study statement

ValPay provides digital wallets in NGN, P2P transfers, top-ups, and auditable transaction history. Users are retail customers; internal users include compliance, finance, and support. Data includes customers, wallet accounts, double-entry ledger postings, transfers, beneficiaries, and audit events. Operations include balance-checked transfers, idempotent payment APIs, reversals, statements, and fraud monitoring (MongoDB in Portfolio 4).

## 2. Portfolio summary

| # | Activity | Location |
|---|----------|----------|
| 1 | Database design and modelling | `portfolio-1-database-design/` |
| 2 | Query processing and optimisation | `portfolio-2-query-optimisation/` |
| 3 | Transactions and concurrency | `portfolio-3-transactions-concurrency/` |
| 4 | NoSQL and advanced data models | `portfolio-4-nosql/` |
| 5 | Distributed and cloud database exercise | `portfolio-5-distributed-cloud/` |

Evidence text outputs: run `./scripts/init_and_evidence.sh`.

## 3. Technical reflection

A ledger + wallet balance model mirrors fintech constraints: balances must match controlled debits and credits. SQLite demonstrates the same transaction patterns as PostgreSQL for production ValPay. NoSQL stores KYC and behavioural events without weakening ledger ACID. The main lesson is polyglot persistence—money stays relational; analytics stays document-oriented.

## 4. References

- Miva Open University. (2026). *MIT 8103 CA brief — September cohort 2026*.
- SQLite Project. https://www.sqlite.org/docs.html
- MongoDB Inc. https://www.mongodb.com/docs/
- Nigeria Data Protection Act 2023 (NDPA).

## 5. AI use declaration

Cursor AI assisted with scaffolding, SQL/Mongo examples, and documentation. All SQL was executed via `scripts/init_and_evidence.sh`. I verified balances, rollback behaviour, and query results before submission.
