-- Seed data for ValPay (run after schema.sql)

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
