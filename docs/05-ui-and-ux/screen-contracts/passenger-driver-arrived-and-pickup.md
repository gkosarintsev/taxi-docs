# Screen Contract: Passenger Driver Arrived & Pickup Spot (`SCR-RIDER-006`)

This specification defines the passenger-facing pickup HUD when the driver has arrived at the pickup location, displaying high-contrast vehicle identification, a 4-digit security OTP code, a free waiting countdown timer, and secure communication channels.

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

> [!NOTE]
> **Vector UI Wireframe:** View the standalone vector screen mockup: [passenger-driver-arrived.svg](../wireframes/passenger-driver-arrived.svg) ([.puml source](../wireframes/passenger-driver-arrived.puml)).

![Passenger Driver Arrived & Pickup UI Schema](diagrams/passenger-driver-arrived-and-pickup.svg)

> _Source: [diagrams/passenger-driver-arrived-and-pickup.puml](diagrams/passenger-driver-arrived-and-pickup.puml)_

### 1.1 Bottom Sheet Dynamics & Interaction Hierarchy

| Component Layer              | Visual Design & Hierarchy                                                                   | User Interaction & Dynamic Behavior                                            |
| ---------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Top Status Pill**          | Emerald Green banner (`#059669`) with subtle pulse animation.                               | Tapping opens the safety toolkit / live trip sharing modal.                    |
| **High-Contrast Plate Card** | Large bold font on light slate badge (`7XYZ912`).                                           | Allows instant curbside visual recognition of the approaching vehicle.         |
| **Security OTP Box**         | Deep blue outlined elevated card with 4-digit code (`4 9 1 2`).                             | Prevents passenger boarding the wrong car; trip cannot start without it.       |
| **Wait Timer Bar**           | Dual-stage indicator: Green/Slate ($0-3\text{ min}$) $\rightarrow$ Amber ($>3\text{ min}$). | Dynamically computes and displays accrued waiting fees ($+\$0.45/\text{min}$). |
| **Driver Comms Bar**         | Split buttons for VoIP Call and In-App Chat.                                                | Routes through Twilio/WebRTC voice proxy with virtual number masking.          |


---

## 2. State Transitions & Event Flow

```mermaid
stateDiagram-v2
    [*] --> DRIVER_ARRIVED_NOTIFIED : WebSocket "DRIVER_ARRIVED"
    DRIVER_ARRIVED_NOTIFIED --> FREE_WAITING_COUNTDOWN : Timer Starts (180s)
    FREE_WAITING_COUNTDOWN --> PAID_WAITING_ACTIVE : Elapsed > 180s

    FREE_WAITING_COUNTDOWN --> TRIP_STARTED : WebSocket "TRIP_STARTED" (OTP Verified)
    PAID_WAITING_ACTIVE --> TRIP_STARTED : WebSocket "TRIP_STARTED"

    PAID_WAITING_ACTIVE --> DRIVER_NO_SHOW_CANCELLED : Driver cancels after 5 mins no-show
    FREE_WAITING_COUNTDOWN --> RIDER_CANCELLED : Rider taps Cancel (Fee applies if >2 min)

    TRIP_STARTED --> [*] : Transition to SCR-RIDER-007 (Active In-Transit Tracking)
```

---

## 3. WebSocket Real-Time Inbound Payload

```json
{
  "event": "DRIVER_ARRIVED",
  "ride_id": "ride_77218",
  "arrived_at": "2026-08-16T14:15:30Z",
  "free_wait_seconds": 180,
  "paid_wait_rate_per_minute": 0.45,
  "currency": "USD",
  "pickup_otp": "4912",
  "driver_exact_location": {
    "latitude": 37.78972,
    "longitude": -122.40015,
    "bearing": 94.0
  }
}
```
