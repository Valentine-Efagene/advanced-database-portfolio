# Normalisation (ValPay relational schema)

## 1NF

- Ledger amounts are atomic; each posting is one row with one `amount` and `direction`.
- Transfer parties are not duplicated as comma-separated lists — `transfer_detail` holds `from_account_id` and `to_account_id`.

## 2NF

- `ledger_posting` uses surrogate `posting_id`; `amount` depends on the full posting, not part of a composite key.

## 3NF

- Customer identity (`email`, `phone`, `kyc_tier`) lives only on `customer`, not on every transaction row.
- Transfer narration depends on `transaction_id`, not transitively on account numbers stored elsewhere.
- Running balance is stored on `wallet_account` for read performance; it is updated only via controlled transactions (Portfolio 3), not denormalised copies on unrelated tables.

## Double-entry integrity (business rule)

Each successful money movement should produce balanced postings: total debits = total credits for a given `transaction_id`. Portfolio 3 scripts enforce this on P2P transfer.

## Integrity summary

| Rule | Enforcement |
|------|-------------|
| Non-negative balance | `CHECK (balance >= 0)` on `wallet_account` |
| Idempotent API calls | `UNIQUE (idempotency_key)` on `transaction` |
| Traceable reference | `UNIQUE (reference)` on `transaction` |
| No self-transfer | `CHECK` on `transfer_detail` |
