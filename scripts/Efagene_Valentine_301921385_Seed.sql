-- Seed data for ValPay (run after Efagene_Valentine_301921385_P1_Schema.sql)

INSERT INTO customer (email, full_name, phone, kyc_tier) VALUES
  ('valentine.efagene@example.com', 'Valentine Efagene', '+2348010000001', 'TIER2'),
  ('chioma@example.com', 'Chioma Okonkwo', '+2348020000002', 'TIER2'),
  ('support@valpay.demo', 'ValPay Ops Wallet', '+2347000000000', 'TIER3');

INSERT INTO wallet_account (customer_id, account_number, balance, status) VALUES
  (1, 'VP1000000001', 250000.00, 'ACTIVE'),
  (2, 'VP1000000002', 85000.50, 'ACTIVE'),
  (3, 'VP9999999999', 5000000.00, 'ACTIVE');

INSERT INTO beneficiary (customer_id, label, account_number, bank_code) VALUES
  (1, 'Chioma wallet', 'VP1000000002', 'VALPAY'),
  (2, 'Valentine wallet', 'VP1000000001', 'VALPAY');

INSERT INTO wallet_transaction (reference, txn_type, status, amount, idempotency_key, created_at) VALUES
  ('VP-TXN-20260901-001', 'TOPUP', 'SUCCESS', 100000.00, 'idem-topup-001', '2026-09-01 09:00:00'),
  ('VP-TXN-20260915-002', 'TRANSFER', 'SUCCESS', 15000.00, 'idem-xfer-002', '2026-09-15 11:20:00'),
  ('VP-TXN-20261001-003', 'TRANSFER', 'SUCCESS', 5000.00, 'idem-xfer-003', '2026-10-01 08:45:00');

INSERT INTO ledger_posting (transaction_id, account_id, direction, amount) VALUES
  (1, 1, 'CREDIT', 100000.00),
  (1, 3, 'DEBIT', 100000.00),
  (2, 1, 'DEBIT', 15000.00),
  (2, 2, 'CREDIT', 15000.00),
  (3, 2, 'DEBIT', 5000.00),
  (3, 1, 'CREDIT', 5000.00);

INSERT INTO transfer_detail (transaction_id, from_account_id, to_account_id, narration) VALUES
  (2, 1, 2, 'Split lunch reimbursement'),
  (3, 2, 1, 'Repayment');

INSERT INTO transaction_audit (transaction_id, event) VALUES
  (1, 'TOPUP_CONFIRMED'),
  (2, 'TRANSFER_SUCCESS'),
  (3, 'TRANSFER_SUCCESS');

-- ===========================================================================
-- BULK SEED: realistic volume for query optimisation evidence (Portfolio 2)
-- ---------------------------------------------------------------------------
-- The hand-picked rows above keep their IDs and values, so the Q1 statement,
-- the Portfolio 3 balances for accounts 1 and 2 (250,000.00 / 85,000.50) and
-- the references used in Efagene_Valentine_301921385_P3_Transactions.sql (VP-TXN-OK-004, VP-TXN-FAIL-001)
-- still behave the same.
--
-- This section adds:
--   * 200 customers (customer_id 4-203), each with one NGN wallet account
--   * a saved beneficiary for each new customer
--   * 40,000 wallet transactions from 1 Jan 2025 to 31 Oct 2026, with matching
--     transfer_detail, balanced ledger_posting pairs and transaction_audit rows
--   * opening-balance entries so that every wallet balance equals its ledger
--     net (sum of CREDIT postings minus sum of DEBIT postings)
--
-- Rules followed:
--   * Bulk activity never touches accounts 1 and 2. TOPUP and BILL_PAY are
--     settled against the ValPay ops wallet (account 3), as in the original
--     top-up row.
--   * References keep the VP-TXN-YYYYMMDD-NNNNNN format with a 6-digit running
--     number, so they cannot collide with the 3-digit references above or with
--     the ones Efagene_Valentine_301921385_P3_Transactions.sql inserts.
--   * Most transactions are SUCCESS. A small number are FAILED or PENDING
--     (recent ones only), and only SUCCESS rows get ledger postings.
--   * Accounts and amounts are picked with md5() of the row number instead of
--     random(), so every reload gives exactly the same data.
-- ===========================================================================

-- New customers (customer_id 4-203)
INSERT INTO customer (email, full_name, phone, kyc_tier, created_at)
SELECT lower(fn) || '.' || lower(ln) || '.' || lpad(i::text, 3, '0') || '@example.com',
       fn || ' ' || ln,
       '+234803' || lpad((1000000 + i)::text, 7, '0'),
       CASE WHEN i % 10 = 0 THEN 'TIER3'
            WHEN i % 3 = 0  THEN 'TIER1'
            ELSE 'TIER2' END,
       TIMESTAMP '2024-06-01 09:00:00' + (i * INTERVAL '1 day') + ((i * 37) % 600) * INTERVAL '1 minute'
FROM (
    SELECT i,
           (ARRAY['Adaeze','Tunde','Ngozi','Emeka','Funke','Ibrahim','Aisha','Chinedu',
                  'Bola','Kelechi','Yemi','Zainab','Obinna','Amaka','Segun','Halima',
                  'Uche','Temitope','Musa','Ifeoma'])[1 + (i % 20)] AS fn,
           (ARRAY['Okafor','Adeyemi','Bello','Eze','Ogunleye','Abubakar','Nwosu','Balogun',
                  'Okoro','Lawal','Ibe','Danjuma','Afolabi','Uzor','Ojo','Mohammed',
                  'Chukwu','Adebayo','Usman'])[1 + ((i * 7) % 19)] AS ln
    FROM generate_series(1, 200) AS g(i)
) AS names;

-- One wallet per new customer (account_number VP2000000001-VP2000000200).
-- The balance here is the closing balance; opening-balance entries further
-- down make the ledger agree with it. About 1 in 25 accounts sits below the 10,000 NGN monitoring threshold (Q4),
-- and a handful are FROZEN.
INSERT INTO wallet_account (customer_id, account_number, balance, status, opened_at)
SELECT c.customer_id,
       'VP2' || lpad(i::text, 9, '0'),
       CASE WHEN i % 25 = 0 THEN ((i * 37) % 9000 + 500)::numeric + ((i * 13) % 100) / 100.0
            ELSE ((i * i * 7919 + i * 104729) % 900000 + 15000)::numeric + ((i * 29) % 100) / 100.0 END,
       CASE WHEN i % 40 = 7 THEN 'FROZEN' ELSE 'ACTIVE' END,
       c.created_at + INTERVAL '10 minutes'
FROM generate_series(1, 200) AS g(i)
JOIN customer c ON c.phone = '+234803' || lpad((1000000 + i)::text, 7, '0');

-- One saved beneficiary per new customer (another new wallet)
INSERT INTO beneficiary (customer_id, label, account_number, bank_code)
SELECT c.customer_id,
       split_part(c2.full_name, ' ', 1) || ' wallet',
       'VP2' || lpad(j::text, 9, '0'),
       'VALPAY'
FROM (SELECT i, ((i * 7) % 200) + 1 AS j FROM generate_series(1, 200) AS g(i)) AS p
JOIN customer c  ON c.phone  = '+234803' || lpad((1000000 + p.i)::text, 7, '0')
JOIN customer c2 ON c2.phone = '+234803' || lpad((1000000 + p.j)::text, 7, '0')
WHERE p.i <> p.j;

-- Working set of generated transactions (temporary, dropped at the end).
-- h1-h4 are deterministic pseudo-random numbers taken from md5(row number).
CREATE TEMP TABLE bulk_txn AS
WITH base AS (
    SELECT n,
           ('x' || substr(md5(n || ':from'),   1, 8))::bit(32)::bigint AS h1,
           ('x' || substr(md5(n || ':to'),     1, 8))::bit(32)::bigint AS h2,
           ('x' || substr(md5(n || ':amount'), 1, 8))::bit(32)::bigint AS h3,
           ('x' || substr(md5(n || ':kobo'),   1, 8))::bit(32)::bigint AS h4,
           -- spread evenly from 2025-01-01 to 2026-10-31, with a little jitter
           TIMESTAMP '2025-01-01 00:00:00'
             + floor((n - 1) * (EXTRACT(EPOCH FROM TIMESTAMP '2026-11-01' - TIMESTAMP '2025-01-01') / 40000)) * INTERVAL '1 second'
             + ((n * 7919) % 1200) * INTERVAL '1 second' AS created_at,
           CASE WHEN n % 20 < 14 THEN 'TRANSFER'
                WHEN n % 20 < 17 THEN 'TOPUP'
                ELSE 'BILL_PAY' END AS txn_type,
           -- about 20 FAILED spread across the period; about 13 PENDING, all in
           -- the last few weeks (old transactions would have settled by now)
           CASE WHEN n % 1999 = 7 THEN 'FAILED'
                WHEN n > 38000 AND n % 151 = 5 THEN 'PENDING'
                ELSE 'SUCCESS' END AS status
    FROM generate_series(1::bigint, 40000) AS g(n)
), picked AS (
    SELECT b.*,
           (b.h1 % 200) + 1 AS from_idx,
           -- a different wallet from the sender, chosen uniformly
           CASE WHEN (b.h2 % 199) + 1 >= (b.h1 % 200) + 1 THEN (b.h2 % 199) + 2
                ELSE (b.h2 % 199) + 1 END AS to_idx
    FROM base AS b
)
SELECT p.n,
       'VP-TXN-' || to_char(p.created_at, 'YYYYMMDD') || '-' || lpad(p.n::text, 6, '0') AS reference,
       'idem-bulk-' || lpad(p.n::text, 6, '0') AS idempotency_key,
       p.txn_type,
       p.status,
       CASE p.txn_type
            WHEN 'TRANSFER' THEN (p.h3 % 2950 + 50) * 10 + (p.h4 % 100) / 100.0   -- 500.00 to 29,999.99
            WHEN 'TOPUP'    THEN (p.h3 % 196 + 5) * 100.00                         -- 500 to 20,000
            ELSE                 (p.h3 % 951 + 50) * 100.00                        -- 5,000 to 100,000
       END::numeric(18, 2) AS amount,
       p.created_at,
       wf.account_id AS from_account_id,
       wt.account_id AS to_account_id,
       (ARRAY['Rent contribution','Lunch','Fuel money','School fees','Ajo savings',
              'Market shopping','Birthday gift','Repayment','Data subscription','Transport'])[1 + (p.n % 10)] AS narration
FROM picked AS p
JOIN wallet_account wf ON wf.account_number = 'VP2' || lpad(p.from_idx::text, 9, '0')
JOIN wallet_account wt ON wt.account_number = 'VP2' || lpad(p.to_idx::text, 9, '0');

INSERT INTO wallet_transaction (reference, txn_type, status, amount, idempotency_key, created_at)
SELECT reference, txn_type, status, amount, idempotency_key, created_at
FROM bulk_txn
ORDER BY n;

-- Transfer details for every TRANSFER (whatever its status)
INSERT INTO transfer_detail (transaction_id, from_account_id, to_account_id, narration)
SELECT t.transaction_id, b.from_account_id, b.to_account_id, b.narration
FROM bulk_txn b
JOIN wallet_transaction t ON t.reference = b.reference
WHERE b.txn_type = 'TRANSFER'
ORDER BY b.n;

-- Double-entry postings for SUCCESS transactions only (one DEBIT + one CREDIT
-- of the same amount). Account 3 is the ValPay ops wallet:
--   TRANSFER: sender DEBIT, receiver CREDIT
--   TOPUP:    ops wallet DEBIT, customer CREDIT
--   BILL_PAY: customer DEBIT, ops wallet CREDIT (biller settlement)
INSERT INTO ledger_posting (transaction_id, account_id, direction, amount, posted_at)
SELECT t.transaction_id, x.account_id, x.direction, b.amount, b.created_at + INTERVAL '2 seconds'
FROM bulk_txn b
JOIN wallet_transaction t ON t.reference = b.reference
CROSS JOIN LATERAL (
    VALUES
      (1, CASE b.txn_type WHEN 'TOPUP' THEN 3 ELSE b.from_account_id END, 'DEBIT'),
      (2, CASE b.txn_type WHEN 'BILL_PAY' THEN 3 ELSE b.to_account_id END, 'CREDIT')
) AS x(seq, account_id, direction)
WHERE b.status = 'SUCCESS'
ORDER BY b.n, x.seq;

-- Audit trail: every transaction is initiated; finished ones get a final event
INSERT INTO transaction_audit (transaction_id, event, logged_at)
SELECT t.transaction_id, e.event, b.created_at + e.delay
FROM bulk_txn b
JOIN wallet_transaction t ON t.reference = b.reference
CROSS JOIN LATERAL (
    VALUES
      (1, b.txn_type || '_INITIATED', INTERVAL '0 seconds'),
      (2, CASE
            WHEN b.status = 'FAILED' THEN b.txn_type || '_FAILED'
            WHEN b.status = 'SUCCESS' AND b.txn_type = 'TOPUP' THEN 'TOPUP_CONFIRMED'
            WHEN b.status = 'SUCCESS' THEN b.txn_type || '_SUCCESS'
          END, INTERVAL '3 seconds')
) AS e(seq, event, delay)
WHERE e.event IS NOT NULL
ORDER BY b.n, e.seq;

DROP TABLE bulk_txn;

-- ===========================================================================
-- OPENING BALANCES: make every wallet balance agree with the ledger
-- ---------------------------------------------------------------------------
-- Each customer wallet gets one opening TOPUP from the ops wallet (account 3)
-- for (balance - ledger net), dated before its other activity:
--   * accounts 1 and 2 on 25 Aug 2026, before their September activity, so
--     they still close at 250,000.00 and 85,000.50 (openings 160,000.00 and
--     75,000.50). Valentine's statement (Q1) shows his as its first line.
--   * bulk wallets one hour after they were opened in 2024.
-- The schema only allows TRANSFER, TOPUP, BILL_PAY and REVERSAL, so openings
-- use TOPUP, with reference VP-OB-<account number> and audit event
-- OPENING_BALANCE.
-- ===========================================================================

CREATE TEMP TABLE opening AS
SELECT wa.account_id,
       wa.account_number,
       wa.balance - COALESCE(SUM(CASE lp.direction WHEN 'CREDIT' THEN lp.amount ELSE -lp.amount END), 0) AS amount,
       CASE WHEN wa.account_id IN (1, 2) THEN TIMESTAMPTZ '2026-08-25 10:00:00'
            ELSE wa.opened_at + INTERVAL '1 hour' END AS created_at
FROM wallet_account wa
LEFT JOIN ledger_posting lp ON lp.account_id = wa.account_id
WHERE wa.account_id <> 3
GROUP BY wa.account_id, wa.account_number, wa.balance, wa.opened_at;

-- Stop here if any wallet would need a zero or negative opening amount
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM opening WHERE amount <= 0) THEN
        RAISE EXCEPTION 'Seed error: % wallet(s) would need a non-positive opening balance',
            (SELECT COUNT(*) FROM opening WHERE amount <= 0);
    END IF;
END $$;

INSERT INTO wallet_transaction (reference, txn_type, status, amount, idempotency_key, created_at)
SELECT 'VP-OB-' || account_number, 'TOPUP', 'SUCCESS', amount, 'idem-ob-' || account_number, created_at
FROM opening
ORDER BY account_id;

INSERT INTO ledger_posting (transaction_id, account_id, direction, amount, posted_at)
SELECT t.transaction_id, x.account_id, x.direction, o.amount, o.created_at
FROM opening o
JOIN wallet_transaction t ON t.reference = 'VP-OB-' || o.account_number
CROSS JOIN LATERAL (VALUES (1, 3::bigint, 'DEBIT'), (2, o.account_id, 'CREDIT')) AS x(seq, account_id, direction)
ORDER BY o.account_id, x.seq;

INSERT INTO transaction_audit (transaction_id, event, logged_at)
SELECT t.transaction_id, 'OPENING_BALANCE', o.created_at
FROM opening o
JOIN wallet_transaction t ON t.reference = 'VP-OB-' || o.account_number
ORDER BY o.account_id;

DROP TABLE opening;

-- The ops wallet's own float is funded from ValPay's settlement bank account.
-- The bank side sits outside the wallet ledger, so this is the only entry with
-- a single (CREDIT) posting. It is sized so account 3 still closes at
-- 5,000,000.00.
INSERT INTO wallet_transaction (reference, txn_type, status, amount, idempotency_key, created_at)
SELECT 'VP-OB-' || wa.account_number, 'TOPUP', 'SUCCESS',
       wa.balance - COALESCE(SUM(CASE lp.direction WHEN 'CREDIT' THEN lp.amount ELSE -lp.amount END), 0),
       'idem-ob-' || wa.account_number, TIMESTAMPTZ '2024-01-01 08:00:00'
FROM wallet_account wa
LEFT JOIN ledger_posting lp ON lp.account_id = wa.account_id
WHERE wa.account_id = 3
GROUP BY wa.account_id, wa.account_number, wa.balance;

INSERT INTO ledger_posting (transaction_id, account_id, direction, amount, posted_at)
SELECT transaction_id, 3, 'CREDIT', amount, created_at
FROM wallet_transaction WHERE reference = 'VP-OB-VP9999999999';

INSERT INTO transaction_audit (transaction_id, event, logged_at)
SELECT transaction_id, 'OPENING_BALANCE', created_at
FROM wallet_transaction WHERE reference = 'VP-OB-VP9999999999';

-- Bulk wallets: store the balance straight from the ledger
UPDATE wallet_account wa
SET balance = n.net
FROM (SELECT account_id,
             SUM(CASE direction WHEN 'CREDIT' THEN amount ELSE -amount END) AS net
      FROM ledger_posting GROUP BY account_id) AS n
WHERE n.account_id = wa.account_id
  AND wa.account_id > 3;

-- Final check: every wallet balance must equal its ledger net
DO $$
DECLARE
    mismatches INT;
BEGIN
    SELECT COUNT(*) INTO mismatches
    FROM wallet_account wa
    LEFT JOIN (SELECT account_id,
                      SUM(CASE direction WHEN 'CREDIT' THEN amount ELSE -amount END) AS net
               FROM ledger_posting GROUP BY account_id) n ON n.account_id = wa.account_id
    WHERE wa.balance <> COALESCE(n.net, 0);
    IF mismatches > 0 THEN
        RAISE EXCEPTION 'Seed error: % wallet(s) do not reconcile with the ledger', mismatches;
    END IF;
END $$;

-- Refresh planner statistics so EXPLAIN reflects the real table sizes
ANALYZE;
