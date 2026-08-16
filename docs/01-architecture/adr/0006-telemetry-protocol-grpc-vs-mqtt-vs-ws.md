# ADR-0006: Telemetry Protocol Selection for Mobile Driver Ingestion: gRPC Streaming vs. WebSocket vs. MQTT

- **Status:** Accepted
- **Deciders:** Mobile Platform Lead, Telemetry Ingestion Architect, Edge Infrastructure Lead
- **Date:** 2026-02-15
- **Technical Story:** PROTO-INGEST-006 (High-Throughput Mobile Telemetry Stream Protocol)

---

## Context and Problem Statement

Active mobile drivers transmit high-frequency telemetry packets every **1 to 2 seconds**:
$$\{ \text{driver\_id}, \text{timestamp}, \text{lat}, \text{lon}, \text{bearing}, \text{speed}, \text{accuracy}, \text{battery}, \text{network\_state} \}$$

Across 100,000 active concurrent drivers, this generates over **50,000–100,000 incoming updates/sec**. Cellular mobile networks (4G/5G) present unique challenges:

1. High packet loss, variable radio latency, and frequent carrier IP handovers.
2. Battery consumption and cellular data usage on driver devices.
3. High TLS handshake overhead if connections are constantly renegotiated.

We need to select the optimal transport protocol and serialization format for driver telemetry ingestion.

---

## Decision Drivers

- **Bandwidth & Serialization Overhead:** Binary compact serialization with minimal header bloat.
- **Connection Multiplexing & Reconnection Speed:** Multiplexing multiple data streams over a single long-lived TCP/TLS connection with fast session resumption (TLS 1.3 0-RTT).
- **Battery & CPU Efficiency on Mobile Devices:** Low serialization/deserialization CPU load.
- **Bidirectional Communication:** Ability for the server to push high-urgency ride offers down the same connection while receiving location updates.
- **Server-Side Load Balancing & Proxies:** Native support in Envoy Gateway and Kubernetes ingress controllers.

---

## Comparative Protocol Evaluation

| Evaluation Criteria             | gRPC Bidirectional Streaming (HTTP/2 + Protobuf)    | WebSocket (RFC 6455 + JSON/Binary)                           | MQTT v5.0 (TCP / QoS 0/1)                       |
| :------------------------------ | :-------------------------------------------------- | :----------------------------------------------------------- | :---------------------------------------------- |
| **Payload Format**              | Strongly-typed Protobuf v3 (Compact binary)         | Unstructured (JSON or custom binary)                         | Binary payload                                  |
| **Payload Size / Update**       | $\mathbf{\approx 42\text{ bytes}}$                  | $\approx 180\text{ bytes (JSON)} / 50\text{ bytes (Binary)}$ | $\approx 48\text{ bytes}$                       |
| **Multiplexing**                | Native HTTP/2 streams over 1 TCP connection         | 1 connection per stream / custom framing                     | Topic-based pub/sub                             |
| **Envoy / K8s Support**         | **First-class native support** (gRPC health, stats) | Connection upgrading required                                | Requires dedicated MQTT Broker (EMQX/Mosquitto) |
| **Client Code Generation**      | Automatic via `protoc` (Swift, Kotlin, Flutter)     | Manual parser implementation                                 | MQTT client SDK integration                     |
| **Flow Control & Backpressure** | Native HTTP/2 window flow control                   | Manual application-level buffer management                   | QoS ack mechanisms                              |

---

## Decision Outcome

Chosen option: **gRPC Bidirectional Streaming over HTTP/2 with Protocol Buffers v3** (with WebSocket fallback for web clients).

### Architecture

```
[ Driver Mobile App (iOS / Android) ]
      │
      │ gRPC Bidirectional Stream over TLS 1.3
      ▼
[ Envoy Edge Gateway (Proxy Protocol + TLS Termination) ]
      │
      │ Internal gRPC (mTLS Istio)
      ▼
[ Location Ingestion Service (Go netpoll) ]
      │
      ▼
[ Redis Cluster & Kafka Topic: driver.telemetry.raw ]
```

### Rationale

- **Protobuf Efficiency:** Binary protobuf reduces cellular bandwidth usage by $\approx 76\%$ compared to standard JSON WebSockets, saving significant cellular data and battery life for driver partners.
- **Unified Contract Definition:** Protobuf files (`location_v1.proto`, `matching_v1.proto`) act as the single source of truth for both iOS/Android client teams and backend microservices.
- **Native Envoy Ingress Load Balancing:** Envoy provides native L7 gRPC stream load balancing and connection draining without breaking client sessions.

---

## Fallback Strategy

For web-based clients (B2B Dispatch Portal, Browser Operations Console) where native raw HTTP/2 gRPC streaming is constrained by browser APIs:

- The API Gateway supports **WebSocket (WSS)** and **gRPC-Web** translation.
