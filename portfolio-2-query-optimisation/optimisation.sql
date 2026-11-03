-- Portfolio 2: index optimisation and EXPLAIN plans (PostgreSQL)

DROP INDEX IF EXISTS idx_transaction_reference;

\echo '--- EXPLAIN Q3 BEFORE (no idx_transaction_reference) ---'
EXPLAIN (FORMAT TEXT)
SELECT t.transaction_id, t.reference, t.amount
FROM wallet_transaction t
WHERE t.reference LIKE 'VP-TXN-202610%';

-- text_pattern_ops lets LIKE 'prefix%' searches use this index under a non-C collation such as en_US.utf8
CREATE INDEX idx_transaction_reference ON wallet_transaction(reference text_pattern_ops);

\echo '--- EXPLAIN Q3 AFTER (idx_transaction_reference) ---'
EXPLAIN (FORMAT TEXT)
SELECT t.transaction_id, t.reference, t.amount
FROM wallet_transaction t
WHERE t.reference LIKE 'VP-TXN-202610%';

\echo '--- EXPLAIN Q1 (ledger by account via join) ---'
EXPLAIN (FORMAT TEXT)
SELECT t.reference, lp.amount
FROM customer c
JOIN wallet_account wa ON wa.customer_id = c.customer_id
JOIN ledger_posting lp ON lp.account_id = wa.account_id
JOIN wallet_transaction t ON t.transaction_id = lp.transaction_id
WHERE c.email = 'valentine.efagene@example.com';
