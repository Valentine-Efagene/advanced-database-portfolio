# Case study: ValPay (your fintech — portfolio simulation)

**Organisation:** **ValPay** — mobile wallet and payments platform (aligned with the fintech you are building). Replace the name in your final PDF if your live product uses a different brand.

**Nature of the system:** Digital wallet, peer-to-peer transfers, bank/card top-ups, bill payments, and transaction history with audit trails.

**Database users:**

| Role | Use of data |
|------|-------------|
| Retail customers | Send/receive money, view balance and history |
| Compliance / ops | KYC review, fraud holds, dispute investigation |
| Finance | Reconciliation, reporting, ledger integrity |
| Support | Trace transfers by reference, reverse failed payouts |

**Major data stored:** customers, KYC tier, wallet accounts (NGN), beneficiaries, transactions, ledger postings (double-entry), transfer metadata, audit log.

**Key operations supported:**

- Onboard customer and open wallet account
- Credit wallet (top-up) and debit (transfer, bill pay)
- P2P transfer with balance check and idempotency
- Reverse or mark failed transactions; append audit entries
- Statement queries and daily volume reporting
- Flag high-risk activity (complement MongoDB event stream in Portfolio 4)

This scenario is used consistently across Portfolio 1–5.
