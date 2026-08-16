# ADR-0003: PostgreSQL for Immutable Double-Entry Billing Ledger & Financial Transactions

- **Status:** Accepted
- **Deciders:** Principal Financial Engineer, Billing Lead, Platform Security Architect
- **Date:** 2026-01-28
- **Technical Story:** FIN-LEDGER-003 (Financial Ledger Architecture & Transactional Consistency)

---

## Context and Problem Statement

The platform orchestrates millions of dollars in financial transactions daily across multiple counterparties:

1. **Passengers:** Pre-authorization holds, capture, cancellations, promo discounts, dispute refunds.
2. **Drivers:** Net earnings accruals, platform commission deductions, tips, weekly/instant bank payouts.
3. **B2B Corporate Clients:** Post-paid invoicing, corporate credit lines, deposit drawdowns.
4. **Platform / Regional Entities:** Revenue recognition, value-added taxes (VAT), acquirer transaction processing fees.

Single-table balance updates (`UPDATE accounts SET balance = balance + 100`) are strictly prohibited due to race conditions, lack of auditability, and non-compliance with financial accounting standards. We require a storage engine and data pattern guaranteeing strict ACID compliance, serializable transactions, and immutable double-entry journal records.

---

## Decision Drivers

- **Strict ACID Compliance & Serializable Isolation:** Zero tolerance for phantom reads, negative balance drifts, or lost updates during concurrent operations.
- **Double-Entry Bookkeeping Invariants:** Every transaction must balance to zero ($\sum \text{Debits} = \sum \text{Credits}$).
- **Audit Trail & Immutability:** Historical ledger postings must be strictly immutable (correction via compensating transactions only).
- **Multi-AZ Replication & Zero RPO:** Complete synchronous commit replication across Availability Zones to prevent financial data loss during infrastructure outages.

---

## Considered Options

1. **PostgreSQL (AWS Aurora Multi-AZ with Read Replicas)**
2. **MongoDB / DocumentDB**
3. **Distributed SQL (CockroachDB / TiDB)**
4. **Custom Ledger on Cassandra / ScyllaDB**

---

## Decision Outcome

Chosen option: **PostgreSQL (with Immutable Double-Entry Ledger Pattern)**.

### Rationale

- **Battle-Tested ACID Guarantees:** PostgreSQL provides rock-solid transaction isolation levels (including `SERIALIZABLE` and `REPEATABLE READ`), constraint enforcement (`CHECK`, `FOREIGN KEY`), and row-level locking (`SELECT FOR UPDATE`).
- **Immutable Ledger Design:** We implement a double-entry ledger consisting of two primary tables: `ledger_journals` and `ledger_entries`. Ledger entries are append-only.
- **Transactional Triggers & Constraints:** Database constraints verify at commit time that $\sum \text{amount} = 0$ for every journal batch.
- **Enterprise Ecosystem:** Native support for logical replication, backup tooling (pgBackRest, AWS Aurora continuous snapshots), and robust connection pooling (PgBouncer).

---

## Double-Entry Ledger Schema Pattern

```sql
-- Enforces immutable append-only ledger entries
CREATE TABLE ledger_journals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    reference_type VARCHAR(64) NOT NULL, -- e.g. 'RIDE_PAYMENT', 'DRIVER_PAYOUT'
    reference_id VARCHAR(128) NOT NULL,
    description TEXT NOT NULL,
    posted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE TABLE ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journal_id UUID NOT NULL REFERENCES ledger_journals(id) ON DELETE RESTRICT,
    account_id UUID NOT NULL REFERENCES ledger_accounts(id),
    amount NUMERIC(18, 4) NOT NULL, -- Positive for Debit, Negative for Credit
    currency VARCHAR(3) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Zero-sum verification trigger on Journal completion
CREATE OR REPLACE FUNCTION verify_journal_zero_sum() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT SUM(amount) FROM ledger_entries WHERE journal_id = NEW.journal_id) != 0.0000 THEN
        RAISE EXCEPTION 'Double-entry violation: Journal % does not balance to zero', NEW.journal_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

---

## Negative Consequences & Mitigation

- **Throughput Ceiling for Single-Node Writes:**
  - _Mitigation:_ Shard billing accounts logically by `tenant_id` / geographical market partition if single-node write saturation is approached.
- **Rapid Table Growth:**
  - _Mitigation:_ Implement PostgreSQL table partitioning by month (`PARTITION BY RANGE (created_at)`) with read-only cold storage archiving to Amazon S3 / ClickHouse after 12 months.
