# ADR-0004: Transactional Outbox Pattern with Debezium CDC for Reliable Event Publishing

- **Status:** Accepted
- **Deciders:** Principal Architect, Core Backend Lead, Data Platform Lead
- **Date:** 2026-02-05
- **Technical Story:** ARCH-REL-004 (Dual-Write Elimination & Exactly-Once Semantics)

---

## Context and Problem Statement

When updating state in a relational database (e.g. creating an order or capturing a payment in PostgreSQL) and simultaneously publishing an event to Apache Kafka (`order.created`, `billing.captured`), a classic **Dual-Write Distributed Failure** occurs:

1. If the database transaction commits, but the Kafka producer fails (e.g. network timeout or broker unreachable), downstream services never receive the event (lost messages).
2. If the event is published to Kafka first, but the database transaction rolls back, downstream services act on a phantom event that does not exist in the database (ghost rides, unpaid captures).

Two-Phase Commit (2PC / XA transactions) across PostgreSQL and Kafka is unsupported and adds unacceptable latency overhead ($> 200\text{ms}$). We require a mechanism that guarantees **At-Least-Once event publishing with Zero Data Loss** and strict ordering without slowing down transaction commit times.

---

## Decision Drivers

- **Zero Event Loss Guarantee:** If and only if a database transaction commits, the corresponding event must eventually be published to Kafka.
- **Low Latency on API Requests:** API write operations must not wait for external message broker acks.
- **Preservation of Partition Order:** Sequential entity state transitions (`REQUESTED` $\to$ `ALLOCATED` $\to$ `COMPLETED`) must maintain strict chronological order.
- **Zero Overhead on DB Locks:** Avoid locking tables for message dispatch polling.

---

## Considered Options

1. **Transactional Outbox Table with Debezium CDC (Change Data Capture)**
2. **Transactional Outbox Table with Scheduled Polling Worker**
3. **Application Dual-Write with Local In-Memory Retry Queue**
4. **PostgreSQL LISTEN / NOTIFY mechanism**

---

## Decision Outcome

Chosen option: **Transactional Outbox Table with Debezium CDC (Logical Replication)**.

### Architecture

```
[ Microservice ]
      │
      ▼ (Atomic DB Transaction)
┌──────────────────────────────────────────────┐
│ PostgreSQL                                   │
│  ├── INSERT INTO rides (...)                 │
│  └── INSERT INTO outbox_events (...)         │
│           │                                  │
│           ▼ (WAL - Write Ahead Log)          │
│     [ PostgreSQL Logical Decoding (pgoutput) ]
└──────────────────────────────────────────────┘
      │
      ▼ (CDC Stream)
[ Debezium Kafka Connect Source Connector ]
      │
      ▼ (Partition Key: payload.aggregate_id)
[ Apache Kafka Topics (order.events / billing.events) ]
```

### Rationale

- **Atomic Commitment:** The domain mutation and the event record are written within the same local PostgreSQL transaction:
  ```sql
  BEGIN;
  UPDATE rides SET status = 'ALLOCATED', driver_id = 'drv_101' WHERE id = 'ride_77218';
  INSERT INTO outbox_events (id, aggregate_type, aggregate_id, event_type, payload, created_at)
  VALUES (gen_random_uuid(), 'RIDE', 'ride_77218', 'ORDER_ALLOCATED', '{"driver_id": "drv_101"}', NOW());
  COMMIT;
  ```
- **Zero Polling Overhead:** Debezium reads the PostgreSQL WAL (Write-Ahead Log) asynchronously using the `pgoutput` logical decoding plugin, delivering events to Kafka with sub-second latency ($\approx 15-50\text{ms}$) without issuing `SELECT ... FOR UPDATE` table locks.
- **Ordered Kafka Partitioning:** Debezium extracts `aggregate_id` (e.g. `ride_id`) as the Kafka message partition key, ensuring strict chronological ordering within the partition.

---

## Negative Consequences & Mitigation

- **Operational Dependency on Kafka Connect:**
  - _Mitigation:_ Run Debezium in high-availability mode on Kubernetes using Strimzi Kafka Connect with automated Prometheus lag alerting.
- **Outbox Table Storage Growth:**
  - _Mitigation:_ Implement pg_partman table partitioning by day and truncate processed outbox rows older than 7 days via automated cron.
