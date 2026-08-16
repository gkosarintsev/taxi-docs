# ADR-0001: Adoption of Apache Kafka as the Core Distributed Event Streaming Bus

- **Status:** Accepted
- **Deciders:** Chief Architect, Platform Infrastructure Lead, Core Backend Guild
- **Date:** 2026-01-15
- **Technical Story:** ARCH-CORE-001 (Distributed Event Spine & Asynchronous Decoupling)

---

## Context and Problem Statement

An on-demand urban mobility platform relies heavily on real-time asynchronous data feeds:

1. High-frequency driver GPS coordinate streams (50,000+ coordinates/second at peak).
2. Order lifecycle state transitions (`Created`, `Matched`, `Arrived`, `InTransit`, `Completed`).
3. Payment, billing, surge pricing triggers, and audit trails.

A synchronous HTTP/REST communication model between all microservices results in tight coupling, cascading failures during network partitions, and inability to handle bursty spikes. We need an event backbone that guarantees:

- High ingest throughput and low latency (< 15ms producer write latency).
- Strict partition-level ordering for ordered state machines (e.g. order state updates).
- Multi-consumer pub/sub pattern allowing real-time consumers (Matching, Notification, WebSocket Gateways) and batch consumers (ClickHouse analytics, Fraud Detection) to read the same stream independently.
- Message retention and replayability for disaster recovery and system debugging.

---

## Decision Drivers

- **High Write Throughput & Scalability:** Must scale to over 100,000 msg/sec without latency degradation.
- **Partitioned Ordering Guarantees:** Events for the same `order_id` or `driver_id` must be consumed in strict temporal order.
- **Consumer Group Fan-out & Independent Offsets:** Multiple downstream microservices consume the same domain events at different rates.
- **Replay Capability:** Ability to re-consume events from historical offsets during service recovery or algorithm backtesting.
- **Ecosystem Maturity:** Robust Kafka Connect ecosystem for CDC (Change Data Capture) and analytical sink to ClickHouse.

---

## Considered Options

1. **Apache Kafka (KRaft mode)**
2. **RabbitMQ (AMQP / Quorum Queues)**
3. **AWS SQS + SNS / Google Cloud Pub/Sub (Managed Cloud Queues)**
4. **Redis Streams**

---

## Decision Outcome

Chosen option: **Apache Kafka (KRaft mode)**.

### Rationale

- **Partition-based ordering:** By partitioning by `order_id` or `city_h3_res4_id`, all sequential events for an entity land in the same partition, guaranteeing ordered consumption.
- **Log Retention & Replay:** Kafka treats events as an append-only commit log with configurable retention (e.g., 7 days for telemetry, 30 days for order events).
- **High Throughput:** Zero-copy OS page cache reads and sequential disk writes allow Kafka to easily sustain 100k+ writes/sec on cost-effective node clusters.
- **KRaft Mode:** Eliminates external ZooKeeper dependencies, simplifying cluster lifecycle and partition rebalancing.

---

## Partitioning Strategy & Topic Topology

| Topic Name                   | Partition Key    | Retention Period | Compaction / Cleanup | Target Throughput |
| :--------------------------- | :--------------- | :--------------- | :------------------- | :---------------- |
| `driver.telemetry.raw`       | `driver_id`      | 24 Hours         | Delete               | 50,000 msg/sec    |
| `driver.telemetry.snapped`   | `h3_res7_index`  | 48 Hours         | Delete               | 40,000 msg/sec    |
| `order.lifecycle.events`     | `order_id`       | 30 Days          | Compact + Delete     | 5,000 msg/sec     |
| `billing.transaction.events` | `account_id`     | 90 Days          | Compact              | 1,500 msg/sec     |
| `dispatch.match.offers`      | `match_round_id` | 7 Days           | Delete               | 8,000 msg/sec     |

---

## Negative Consequences & Mitigation

- **Operational Complexity:**
  - _Mitigation:_ Deploy via Strimzi Kafka Operator on Kubernetes with automated Prometheus metrics and Cruise Control for dynamic partition rebalancing.
- **Duplicate Processing Risk (At-least-once Delivery):**
  - _Mitigation:_ Require strict idempotency keys on all consumer handlers and use transactional outbox patterns with PostgreSQL for reliable publishing.
