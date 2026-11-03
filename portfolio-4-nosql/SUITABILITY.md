# NoSQL suitability for ValPay

## Relational core (PostgreSQL)

Balances, ledger postings, and transfer status require **ACID** and referential integrity. This must stay relational.

## Document store (MongoDB)

**KYC payloads** vary by document type (NIN vs utility bill fields). Embedding them in `metadata` avoids wide nullable columns in SQL.

**Activity and fraud events** are append-only, high-volume, and queried for time ranges — a natural fit for MongoDB (or a dedicated event store) with TTL indexes for retention under NDPA.

## Sync pattern

Customer `customer_id` in MongoDB maps to relational `customer.customer_id` (or external UUID). Events reference `reference` matching `transaction.reference` for ops tracing without duplicating ledger rows.

## Trade-off

Eventual consistency is acceptable for fraud analytics; **not** for wallet balance — balance updates remain in the relational transaction path (Portfolio 3).
