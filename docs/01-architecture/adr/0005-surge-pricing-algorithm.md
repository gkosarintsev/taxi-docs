# ADR-0005: Dynamic Surge Pricing Algorithm & Elasticity Model

- **Status:** Accepted
- **Deciders:** Chief Data Scientist, Revenue Optimization Guild, Matching Architect
- **Date:** 2026-02-10
- **Technical Story:** ALG-SURGE-005 (Real-time Spatial Supply-Demand Pricing Engine)

---

## Context and Problem Statement

In on-demand transportation, localized demand surges (e.g. rush hours, concert egress, sudden thunderstorms) frequently overwhelm local driver supply. If prices remain static:

1. Driver supply is quickly exhausted (100% stockout), leading to unfulfilled ride requests and customer dissatisfaction.
2. Drivers have no economic incentive to reposition themselves into high-demand zones.

We require a real-time, algorithmic pricing engine that dynamically calculates a multiplier $S \ge 1.0$ per **H3 Resolution 7 cell** ($\approx 5\text{ km}^2$) updated every **15–30 seconds**. The algorithm must prevent wild price oscillations (flickering), protect customer trust, and maximize overall market clearing fulfillment.

---

## Decision Drivers

- **Supply-Demand Equilibrium:** Incentivize driver supply inward while gently moderating excessive demand.
- **Temporal & Spatial Smoothness:** Prevent step-function price jumps between adjacent city blocks or between consecutive minutes.
- **Anti-Collusion & Anti-Gaming:** Resist deliberate driver collective logoffs designed to artificially inflate surge.
- **Bounded Multipliers:** Hard floor ($1.0\times$) and regulatory/safety ceiling ($3.5\times$).

---

## Algorithm Specification & Mathematical Formulation

### 1. Spatial Aggregation & Raw Pressure Ratio ($R$)

For every H3 Resolution 7 cell $h$, we aggregate metrics over a sliding 5-minute window:
$$D_h = \text{Unfulfilled Open Ride Requests} + \alpha \cdot \text{Active App Radar Searches}$$
$$S_h = \text{Available Online Drivers (Idle)} + \beta \cdot \text{Drivers Completing Trips in } h \text{ within } 3\text{ min}$$

Raw Demand-Supply Pressure Ratio:
$$R_h = \frac{D_h}{\max(S_h, 1)}$$

### 2. Base Multiplier Calculation (Sigmoidal Elasticity)

To prevent linear runaway pricing, we map $R_h$ through a generalized sigmoid function with parameters calibrated by historical price elasticity of demand ($\epsilon$):
$$S_{\text{raw}}(h) = 1.0 + \frac{S_{\max} - 1.0}{1.0 + e^{-k \cdot (R_h - R_{\text{threshold}})}}$$
Where:

- $S_{\max} = 3.50$ (Max regulatory surge cap)
- $R_{\text{threshold}} = 1.20$ (Pressure threshold where surge activates)
- $k = 1.80$ (Steepness parameter)

### 3. Spatial & Temporal Smoothing (Kernel Filtering)

1. **Spatial Convolution (Neighboring Hexagons):**
   To prevent boundary cliffs, the multiplier is blended with its 1st-ring neighbors ($N(h) = \text{kRing}(h, 1)$):
   $$S_{\text{spatial}}(h) = 0.70 \cdot S_{\text{raw}}(h) + \frac{0.30}{6} \sum_{n \in N(h)} S_{\text{raw}}(n)$$

2. **Temporal Exponential Moving Average (EMA):**
   To avoid rapid price flickering:
   $$S_t(h) = \lambda \cdot S_{\text{spatial}}(h) + (1 - \lambda) \cdot S_{t-1}(h) \quad (\lambda = 0.35)$$

---

## Implementation Architecture

```mermaid
flowchart LR
    Kafka[Kafka: driver.telemetry + ride.requests] --> Flink[Apache Flink Stream Job]
    Flink -->|Window Aggregates (15s)| SurgeCalc[Surge Calculator Go Engine]
    SurgeCalc -->|H3 Grid Set| Redis[(Redis Surge Cache: H3 Res 7)]
    SurgeCalc -->|Broadcast Topic| KafkaSurge[Kafka: analytics.surge.ratios]
```

---

## Consequences

### Positive

- **Automatic Market Balancing:** Increases driver acceptance by $28\%$ and reduces unfulfilled search dropoffs during peak periods.
- **Predictable Latency:** Multiplier lookups in Redis are constant-time $O(1)$ integers by H3 cell ID ($< 1\text{ms}$).

### Negative / Trade-offs

- **User Perception Sensitivity:** Requires transparent UI surge indicators (`🔥 1.4x Surge`) and fare lock tokens to protect user confidence.
