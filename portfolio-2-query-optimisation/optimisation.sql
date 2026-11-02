-- Portfolio 2: index optimisation and EXPLAIN plans (ValPay)

.echo on

DROP INDEX IF EXISTS idx_transaction_reference;

.print '--- EXPLAIN Q3 BEFORE (no idx_transaction_reference) ---'
EXPLAIN QUERY PLAN
SELECT t.transaction_id, t.reference, t.amount
FROM wallet_transaction t
WHERE t.reference LIKE 'VP-TXN-202610%';

CREATE INDEX idx_transaction_reference ON wallet_transaction(reference);

.print '--- EXPLAIN Q3 AFTER (idx_transaction_reference) ---'
EXPLAIN QUERY PLAN
SELECT t.transaction_id, t.reference, t.amount
FROM wallet_transaction t
WHERE t.reference LIKE 'VP-TXN-202610%';

.print '--- EXPLAIN Q1 (ledger by account via join) ---'
EXPLAIN QUERY PLAN
SELECT t.reference, lp.amount
FROM customer c
JOIN wallet_account wa ON wa.customer_id = c.customer_id
JOIN ledger_posting lp ON lp.account_id = wa.account_id
JOIN wallet_transaction t ON t.transaction_id = lp.transaction_id
WHERE c.email = 'valentine.efagene@example.com';
