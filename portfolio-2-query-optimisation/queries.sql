-- Portfolio 2: representative queries for ValPay fintech

.headers on
.mode column

-- Q1: Wallet statement for a customer (by email)
SELECT t.reference,
       t.txn_type,
       t.status,
       t.created_at,
       lp.direction,
       lp.amount,
       wa.account_number
FROM customer c
JOIN wallet_account wa ON wa.customer_id = c.customer_id
JOIN ledger_posting lp ON lp.account_id = wa.account_id
JOIN wallet_transaction t ON t.transaction_id = lp.transaction_id
WHERE c.email = 'valentine.efagene@example.com'
ORDER BY t.created_at DESC, lp.posting_id;

-- Q2: Daily successful transfer volume
SELECT date(t.created_at) AS day,
       COUNT(*) AS transfer_count,
       ROUND(SUM(t.amount), 2) AS total_amount_ngn
FROM wallet_transaction t
WHERE t.txn_type = 'TRANSFER'
  AND t.status = 'SUCCESS'
GROUP BY date(t.created_at)
ORDER BY day DESC;

-- Q3: Lookup transaction by reference prefix (optimisation candidate)
SELECT t.transaction_id, t.reference, t.amount, t.status
FROM wallet_transaction t
WHERE t.reference LIKE 'VP-TXN-202610%';

-- Q4: Accounts below internal monitoring threshold (example: balance under 10k)
SELECT c.full_name, wa.account_number, wa.balance, wa.status
FROM wallet_account wa
JOIN customer c ON c.customer_id = wa.customer_id
WHERE wa.balance < 10000
  AND wa.status = 'ACTIVE'
ORDER BY wa.balance ASC;

-- Q5: Pending or failed transactions needing ops review
SELECT t.reference, t.txn_type, t.amount, t.status, t.created_at
FROM wallet_transaction t
WHERE t.status IN ('PENDING', 'FAILED')
ORDER BY t.created_at DESC;
