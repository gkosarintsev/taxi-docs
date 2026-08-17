# Screen Contract: Driver Order Offer Modal (`SCR-DRV-003`)

This specification defines the high-urgency 15-second ride offer modal presented to an available driver partner.

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

![Driver Order Offer Modal UI Schema](diagrams/driver-order-offer.svg)

> _Source: [diagrams/driver-order-offer.puml](diagrams/driver-order-offer.puml)_


---

## 2. Timing & Lock Lifecycle

```mermaid
sequenceDiagram
    participant Svc as Dispatch Engine
    participant App as Driver App
    participant Audio as Device Audio / Haptics

    Svc->>App: Push Event: OFFER_DISPATCHED (TTL: 15s)
    App->>Audio: Play continuous loud ringtone & haptic pulse
    App->>App: Start 15s radial countdown animation

    alt Driver Taps Accept (within 15s)
        App->>Svc: POST /api/v1/driver/offers/{offerId}/respond {action: "ACCEPT"}
        Svc-->>App: 200 OK (Assign Ride & Open Navigation)
        App->>Audio: Stop ringtone & trigger success sound
    else Driver Taps Decline OR 15s Expires
        App->>Svc: POST /api/v1/driver/offers/{offerId}/respond {action: "DECLINE"}
        App->>App: Dismiss modal with fade-out
        App->>Audio: Stop ringtone
        App->>App: Re-enter idle radar mode
    end
```

---

## 3. Offer Payload Schema

```json
{
  "offer_id": "off_991823a",
  "ride_id": "ride_77218",
  "expires_at_unix_ms": 1771146435000,
  "timeout_seconds": 15,
  "payout": {
    "amount": 14.8,
    "currency": "USD",
    "surge_amount": 3.2
  },
  "pickup": {
    "address": "450 Market St",
    "distance_meters": 1200,
    "eta_seconds": 180
  },
  "dropoff": {
    "address": "Mission Bay Blvd S",
    "estimated_trip_duration_seconds": 900,
    "estimated_trip_distance_meters": 7200
  },
  "rider": {
    "first_name": "Sarah",
    "rating": 4.92
  }
}
```
