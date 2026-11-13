-- Portfolio 3: P2P transfer with ACID (ValPay, PostgreSQL)

\pset border 2
\pset format aligned

\echo '=== Balances before transfer tests ==='
SELECT account_number, balance FROM wallet_account WHERE account_id <= 3 ORDER BY account_id;

\echo '=== Test A: FAILED transfer — insufficient funds ==='
BEGIN;

INSERT INTO wallet_transaction (reference, txn_type, status, amount, idempotency_key)
VALUES ('VP-TXN-FAIL-001', 'TRANSFER', 'PENDING', 999999.00, 'idem-fail-999');

WITH upd AS (
    UPDATE wallet_account
    SET balance = balance - 999999.00
    WHERE account_id = 1 AND balance >= 999999.00
    RETURNING account_id
)
SELECT COUNT(*)::int AS balance_update_rows FROM upd;

ROLLBACK;

SELECT 'After rollback — no VP-TXN-FAIL-001' AS note,
       COUNT(*) AS cnt FROM wallet_transaction WHERE reference = 'VP-TXN-FAIL-001';
SELECT balance AS valentine_balance FROM wallet_account WHERE account_id = 1;

\echo '=== Test B: SUCCESSFUL P2P transfer 2,500 NGN (account 1 -> 2) ==='
BEGIN;

INSERT INTO wallet_transaction (reference, txn_type, status, amount, idempotency_key)
VALUES ('VP-TXN-OK-004', 'TRANSFER', 'PENDING', 2500.00, 'idem-ok-004-portfolio-demo');

INSERT INTO transfer_detail (transaction_id, from_account_id, to_account_id, narration)
SELECT (SELECT transaction_id FROM wallet_transaction WHERE reference = 'VP-TXN-OK-004'),
       1, 2, 'Portfolio demo transfer';

UPDATE wallet_account SET balance = balance - 2500.00
WHERE account_id = 1 AND balance >= 2500.00;

UPDATE wallet_account SET balance = balance + 2500.00 WHERE account_id = 2;

INSERT INTO ledger_posting (transaction_id, account_id, direction, amount)
SELECT (SELECT transaction_id FROM wallet_transaction WHERE reference = 'VP-TXN-OK-004'), 1, 'DEBIT', 2500.00
UNION ALL
SELECT (SELECT transaction_id FROM wallet_transaction WHERE reference = 'VP-TXN-OK-004'), 2, 'CREDIT', 2500.00;

UPDATE wallet_transaction SET status = 'SUCCESS'
WHERE reference = 'VP-TXN-OK-004';

INSERT INTO transaction_audit (transaction_id, event)
SELECT transaction_id, 'TRANSFER_SUCCESS' FROM wallet_transaction WHERE reference = 'VP-TXN-OK-004';

COMMIT;

\echo '=== After successful transfer ==='
SELECT t.reference, t.status, td.narration, wa.account_number, wa.balance
FROM wallet_transaction t
JOIN transfer_detail td ON td.transaction_id = t.transaction_id
JOIN wallet_account wa ON wa.account_id IN (td.from_account_id, td.to_account_id)
WHERE t.reference = 'VP-TXN-OK-004'
ORDER BY wa.account_id;
