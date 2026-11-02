-- ValPay fintech — relational schema (SQLite 3)
-- Portfolio 1: MIT 8103

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS customer (
    customer_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    email         TEXT NOT NULL UNIQUE,
    full_name     TEXT NOT NULL,
    phone         TEXT NOT NULL UNIQUE,
    kyc_tier      TEXT NOT NULL DEFAULT 'TIER1'
        CHECK (kyc_tier IN ('TIER1', 'TIER2', 'TIER3')),
    created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS wallet_account (
    account_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id      INTEGER NOT NULL REFERENCES customer(customer_id),
    account_number   TEXT NOT NULL UNIQUE,
    currency         TEXT NOT NULL DEFAULT 'NGN' CHECK (currency = 'NGN'),
    balance          REAL NOT NULL DEFAULT 0 CHECK (balance >= 0),
    status           TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED')),
    opened_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS beneficiary (
    beneficiary_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id      INTEGER NOT NULL REFERENCES customer(customer_id) ON DELETE CASCADE,
    label            TEXT NOT NULL,
    account_number   TEXT NOT NULL,
    bank_code        TEXT NOT NULL,
    UNIQUE (customer_id, account_number, bank_code)
);

CREATE TABLE IF NOT EXISTS wallet_transaction (
    transaction_id   INTEGER PRIMARY KEY AUTOINCREMENT,
    reference        TEXT NOT NULL UNIQUE,
    txn_type         TEXT NOT NULL
        CHECK (txn_type IN ('TRANSFER', 'TOPUP', 'BILL_PAY', 'REVERSAL')),
    status           TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'REVERSED')),
    amount           REAL NOT NULL CHECK (amount > 0),
    idempotency_key  TEXT NOT NULL UNIQUE,
    created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS ledger_posting (
    posting_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id   INTEGER NOT NULL REFERENCES wallet_transaction(transaction_id),
    account_id       INTEGER NOT NULL REFERENCES wallet_account(account_id),
    direction        TEXT NOT NULL CHECK (direction IN ('DEBIT', 'CREDIT')),
    amount           REAL NOT NULL CHECK (amount > 0),
    posted_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS transfer_detail (
    transaction_id   INTEGER PRIMARY KEY REFERENCES wallet_transaction(transaction_id),
    from_account_id  INTEGER NOT NULL REFERENCES wallet_account(account_id),
    to_account_id    INTEGER NOT NULL REFERENCES wallet_account(account_id),
    narration        TEXT,
    CHECK (from_account_id <> to_account_id)
);

CREATE TABLE IF NOT EXISTS transaction_audit (
    audit_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id   INTEGER NOT NULL REFERENCES wallet_transaction(transaction_id),
    event            TEXT NOT NULL,
    logged_at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_wallet_customer ON wallet_account(customer_id);
CREATE INDEX IF NOT EXISTS idx_ledger_account ON ledger_posting(account_id);
CREATE INDEX IF NOT EXISTS idx_ledger_txn ON ledger_posting(transaction_id);
CREATE INDEX IF NOT EXISTS idx_transaction_created ON wallet_transaction(created_at);
CREATE INDEX IF NOT EXISTS idx_transaction_reference ON wallet_transaction(reference);
