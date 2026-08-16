-- ============================================================================
-- Urban Mobility Platform: Billing & Double-Entry Accounting Ledger DDL Schema
-- Engine: PostgreSQL 15+
-- File: 002_billing_ledger_schema.sql
-- Reference: ADR-0003 (PostgreSQL for Immutable Double-Entry Ledger)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 1. ENUMS & CONSTANTS
-- ============================================================================

CREATE TYPE ledger_owner_type_enum AS ENUM (
    'RIDER_WALLET', 
    'DRIVER_EARNINGS', 
    'B2B_PARTNER_CREDIT', 
    'PLATFORM_COMMISSION_REVENUE', 
    'PLATFORM_SURGE_POOL', 
    'PSP_CLEARING_STRIPE', 
    'PSP_CLEARING_ADYEN', 
    'TAX_ESCROW_GOVERNMENT'
);

CREATE TYPE journal_reference_type_enum AS ENUM (
    'RIDE_PAYMENT_CAPTURED', 
    'DRIVER_PAYOUT_SETTLED', 
    'RIDER_REFUND_ISSUED', 
    'PROMOTION_SUBSIDY_APPLIED', 
    'DISPUTE_CHARGEBACK_PENALTY', 
    'B2B_MONTHLY_INVOICE_SETTLED'
);

CREATE TYPE psp_transaction_status_enum AS ENUM (
    'INITIATED', 'HOLD_AUTHORIZED', 'CAPTURED', 'VOIDED', 'REFUNDED', 'FAILED'
);

CREATE TYPE payout_status_enum AS ENUM (
    'PENDING_AUDIT', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'REVERSED'
);

-- ============================================================================
-- 2. LEDGER ACCOUNTS (CHART OF ACCOUNTS)
-- ============================================================================

CREATE TABLE ledger_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_number VARCHAR(64) NOT NULL UNIQUE,
    owner_type ledger_owner_type_enum NOT NULL,
    owner_id UUID, -- NULL for platform internal operational accounts
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

CREATE INDEX idx_ledger_accounts_owner ON ledger_accounts(owner_type, owner_id) WHERE owner_id IS NOT NULL;
CREATE INDEX idx_ledger_accounts_num ON ledger_accounts(account_number);

-- ============================================================================
-- 3. LEDGER JOURNALS (TRANSACTION ROOT HEADERS)
-- ============================================================================

CREATE TABLE ledger_journals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID,
    reference_type journal_reference_type_enum NOT NULL,
    reference_id VARCHAR(128) NOT NULL,
    description TEXT NOT NULL,
    posted_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

CREATE INDEX idx_journals_ref ON ledger_journals(reference_type, reference_id);
CREATE INDEX idx_journals_posted_at ON ledger_journals(posted_at DESC);

-- ============================================================================
-- 4. LEDGER ENTRIES (ATOMIC BALANCED MOVEMENTS)
-- ============================================================================

CREATE TABLE ledger_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    journal_id UUID NOT NULL REFERENCES ledger_journals(id) ON DELETE RESTRICT,
    account_id UUID NOT NULL REFERENCES ledger_accounts(id) ON DELETE RESTRICT,
    amount NUMERIC(18, 4) NOT NULL CHECK (amount <> 0.0000), -- Positive = Debit (+), Negative = Credit (-)
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

CREATE INDEX idx_entries_account_balance ON ledger_entries(account_id, created_at);
CREATE INDEX idx_entries_journal_id ON ledger_entries(journal_id);

-- ============================================================================
-- 5. PAYMENT TRANSACTIONS (GATEWAY / PSP AUDIT LOG)
-- ============================================================================

CREATE TABLE payment_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID NOT NULL,
    user_id UUID NOT NULL,
    journal_id UUID REFERENCES ledger_journals(id) ON DELETE RESTRICT,
    psp_name VARCHAR(32) NOT NULL,
    psp_charge_id VARCHAR(128) NOT NULL UNIQUE,
    status psp_transaction_status_enum NOT NULL DEFAULT 'INITIATED',
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    fee_amount NUMERIC(8, 2) NOT NULL DEFAULT 0.00 CHECK (fee_amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    failure_code VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP(),
    settled_at TIMESTAMPTZ
);

CREATE INDEX idx_payment_tx_ride ON payment_transactions(ride_id);
CREATE INDEX idx_payment_tx_psp_id ON payment_transactions(psp_charge_id);

-- ============================================================================
-- 6. PAYOUT BATCHES (BANK TRANSFERS & FLEET DISBURSEMENTS)
-- ============================================================================

CREATE TABLE payout_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    beneficiary_type ledger_owner_type_enum NOT NULL,
    beneficiary_id UUID NOT NULL,
    journal_id UUID REFERENCES ledger_journals(id) ON DELETE RESTRICT,
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount > 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    bank_transfer_reference VARCHAR(128) UNIQUE,
    status payout_status_enum NOT NULL DEFAULT 'PENDING_AUDIT',
    settled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

CREATE INDEX idx_payouts_beneficiary ON payout_batches(beneficiary_type, beneficiary_id, status);

-- ============================================================================
-- 7. ZERO-SUM BALANCING CONSTRAINT (DEFERRED TRANSACTION TRIGGER)
-- ============================================================================

CREATE OR REPLACE FUNCTION check_ledger_journal_balanced()
RETURNS TRIGGER AS $$
DECLARE
    entry_sum NUMERIC(18, 4);
    entry_count INTEGER;
BEGIN
    SELECT COALESCE(SUM(amount), 0), COUNT(*)
    INTO entry_sum, entry_count
    FROM ledger_entries
    WHERE journal_id = NEW.journal_id;

    IF entry_count < 2 THEN
        RAISE EXCEPTION 'Double-entry violation: Journal ID % contains less than 2 balancing entries', NEW.journal_id;
    END IF;

    IF entry_sum <> 0.0000 THEN
        RAISE EXCEPTION 'Double-entry violation: Journal ID % is unbalanced. Total sum is % (expected 0.0000)', 
            NEW.journal_id, entry_sum;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Constraint trigger evaluated at the end of the transaction block (COMMIT)
CREATE CONSTRAINT TRIGGER trg_check_ledger_journal_balanced
AFTER INSERT OR UPDATE ON ledger_entries
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_ledger_journal_balanced();

-- ============================================================================
-- 8. IMMUTABILITY ENFORCEMENT TRIGGER (PREVENTS UPDATE / DELETE)
-- ============================================================================

CREATE OR REPLACE FUNCTION enforce_ledger_immutability()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Security violation: Ledger journals and entries are append-only and strictly immutable. Corrections must be posted as offsetting adjustment journals.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_ledger_entries_immutability
BEFORE UPDATE OR DELETE ON ledger_entries
FOR EACH ROW
EXECUTE FUNCTION enforce_ledger_immutability();

CREATE TRIGGER trg_protect_ledger_journals_immutability
BEFORE UPDATE OR DELETE ON ledger_journals
FOR EACH ROW
EXECUTE FUNCTION enforce_ledger_immutability();
