# Screen Contract: Passenger Ride Search & Driver Matching (`SCR-RIDER-005`)

This contract defines the client-side state machine, WebSocket event bindings, timeout escalation, and UX behavior during driver matching.

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

```mermaid
flowchart TB
    subgraph PhoneFrame ["📱 Smartphone Viewport · Passenger Radar Search (SCR-RIDER-005)"]
        direction TB

        subgraph TopBar ["Layer 1: Top Search Status Bar (Floating Island)"]
            AddressPill["📍 555 Market St ➔ SFO Terminal 2"]
            WaitETA["⏱️ Connecting with nearby drivers (~2-4 min)..."]
        end

        subgraph MapCanvas ["Layer 0: Full-Screen Radar Map Viewport"]
            RadarSweep["📡 Pulsating Concentric Radar Rings (H3 Res 7 Area Sweep)"]
            NearbyDrivers["🚗 4 Candidate Drivers in Vicinity (Simulated Pins)"]
        end

        subgraph BottomSheet ["Layer 2: Search Status & Radar Progress Sheet"]
            direction TB
            subgraph StatusCard ["Matching Progress Information"]
                TariffBadge["🚗 <b>Economy Class · $18.50</b> (⚡ 1.3x Surge Locked)"]
                ProgressTimer["⏳ Finding best driver: <b>0:42 / 3:00</b>"]
            end

            CancelCTA["⚪ <b>CANCEL SEARCH</b> (Immediate 100% Refund)"]
        end
    end

    style PhoneFrame fill:#F8FAFC,stroke:#334155,stroke-width:3px
    style TopBar fill:#FFFFFF,stroke:#94A3B8,stroke-width:2px
    style MapCanvas fill:#E0F2FE,stroke:#0284C7,stroke-width:2px
    style BottomSheet fill:#FFFFFF,stroke:#64748B,stroke-width:2px
    style StatusCard fill:#F8FAFC,stroke:#CBD5E1,stroke-width:1px
    style CancelCTA fill:#FFFFFF,stroke:#EF4444,color:#DC2626,stroke-width:2px
```


---

## 2. State & Event Invariants

```mermaid
stateDiagram-v2
    [*] --> RADAR_SEARCHING : On Mount (POST /api/v1/rides/create 201)
    RADAR_SEARCHING --> EXPANDING_RADIUS : After 45s without match
    EXPANDING_RADIUS --> DRIVER_FOUND : WebSocket "DRIVER_ASSIGNED"
    EXPANDING_RADIUS --> MATCH_TIMEOUT : Elapsed > 180s without match
    RADAR_SEARCHING --> DRIVER_FOUND : WebSocket "DRIVER_ASSIGNED"
    RADAR_SEARCHING --> USER_CANCELLED : User taps "Cancel Search"

    DRIVER_FOUND --> TRANSITION_TO_ACTIVE_RIDE : 500ms Haptic + Screen Slide
    MATCH_TIMEOUT --> SHOW_TIMEOUT_SHEET : Modal with "Retry with Priority Tip"
    USER_CANCELLED --> DISMISS_AND_REFUND : Call DELETE /api/v1/rides/{id}
```

---

## 3. Communication Contract (WebSocket & Polling Fallback)

### WebSocket Inbound Event: `DRIVER_ASSIGNED`

```json
{
  "event": "DRIVER_ASSIGNED",
  "ride_id": "ride_77218",
  "driver": {
    "id": "drv_9921",
    "name": "Alex M.",
    "photo_url": "https://cdn.mobility.io/drivers/drv_9921.jpg",
    "rating": 4.94,
    "total_trips": 2840,
    "vehicle": {
      "make": "Toyota",
      "model": "Camry Hybrid",
      "color": "Silver",
      "license_plate": "7XYZ912"
    },
    "current_location": {
      "latitude": 37.7791,
      "longitude": -122.4201,
      "bearing": 182.0
    },
    "pickup_eta_seconds": 180
  },
  "pickup_otp": "4912"
}
```

### Fallback Polling

If WebSocket disconnects, the client initiates exponential backoff HTTP polling:

- `GET /api/v1/rides/{rideId}/status` every $3\text{ seconds}$ until re-established.
