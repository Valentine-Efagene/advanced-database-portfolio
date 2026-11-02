# Portfolio 2 — Query optimisation (ValPay)

Business queries: wallet statement, daily transfer volume, reference lookup, low-balance monitoring, failed/pending queue.

Index `idx_transaction_reference` improves reference prefix lookup — see `evidence/explain_plans.txt`.
