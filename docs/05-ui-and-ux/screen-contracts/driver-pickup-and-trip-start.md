# Screen Contract: Driver Pickup Spot & Trip Start (`SCR-DRV-003`)

This specification defines the driver terminal behavior upon arriving at the rider's pickup location, including automatic/manual arrival triggering, waiting fee accounting, rider OTP entry & verification, and the swipeable `SLIDE TO START TRIP` gesture action.

---

## 1. Visual UI Layout & Component Hierarchy

> [!NOTE]
> **Vector UI Wireframe:** View the standalone vector screen mockup: [driver-pickup-and-start.svg](../wireframes/driver-pickup-and-start.svg) ([.puml source](../wireframes/driver-pickup-and-start.puml)).

```mermaid
flowchart TB
    subgraph DriverTerminal ["📱 Driver Mobile Terminal Viewport (SCR-DRV-003)"]
        direction TB

        subgraph TopStatus ["Layer 1: Top Arrival Status HUD"]
            StatusText["🟢 <b>✓ YOU ARE AT PICKUP SPOT: 555 Market St</b>"]
            NavPinBtn["📍 Navigate to Exact Pin (Waze / Google Maps / Native)"]
        end

        subgraph MapCanvas ["Layer 0: High-Precision Pickup Spot Map Canvas"]
            Geofence["🗺️ Passenger Pin (Accuracy: ±3m) · Geofence Circle (Radius: 30m)"]
        end

        subgraph BottomHUD ["Layer 2: Bottom Pickup Control Sheet"]
            direction TB
            subgraph RiderCard ["Passenger Information & Communication"]
                RiderInfo["👤 <b>Sarah K.</b> (★ 4.92 · 142 rides)"]
                Comms["📞 Masked VoIP Call · 💬 In-App Chat"]
            end

            subgraph TimerBox ["Dual-Stage Wait Timer HUD"]
                TimerBadge["⏱️ <b>Free Waiting: 02:15</b> (Paid wait starts after 3:00 at $0.45/min)"]
            end

            subgraph OTPBox ["4-Digit Security OTP Keypad Input"]
                OTPInput["🔐 Enter Passenger Code: [ 4 ] [ 9 ] [ 1 ] [ 2 ] · [✓ Verify]"]
            end

            subgraph ActionGestures ["Trip Execution Actions"]
                SlideWidget["🟩 <b>SLIDE TO START TRIP >>>>>>>>></b> (Swipe Right with Haptic Pulse)"]
                NoShowBtn["⚠️ Passenger No-Show (Active after 5:00 min wait · $6.00 Fee)"]
            end
        end
    end

    style DriverTerminal fill:#F8FAFC,stroke:#1E293B,stroke-width:3px
    style TopStatus fill:#ECFDF5,stroke:#059669,stroke-width:2px
    style MapCanvas fill:#E0F2FE,stroke:#0284C7,stroke-width:2px
    style BottomHUD fill:#FFFFFF,stroke:#475569,stroke-width:2px
    style RiderCard fill:#F1F5F9,stroke:#94A3B8,stroke-width:1px
    style TimerBox fill:#FEF3C7,stroke:#D97706,stroke-width:1px
    style OTPBox fill:#EFF6FF,stroke:#3B82F6,stroke-width:1px
    style SlideWidget fill:#10B981,stroke:#047857,color:#FFFFFF,stroke-width:2px
    style NoShowBtn fill:#FEE2E2,stroke:#EF4444,color:#991B1B,stroke-width:1px
```

### 1.1 Touch & Gesture Safety Invariants

- **Why a Slider instead of a Button?** While operating a motor vehicle, sudden road vibrations or bumps can cause accidental screen taps. Using a linear `Slide-to-Confirm` swipe gesture requiring $250\text{ pixels}$ of continuous horizontal finger travel prevents false trip starts or unintended cancellations.

---

## 2. Driver Pickup State Machine

```mermaid
stateDiagram-v2
    [*] --> EN_ROUTE_TO_PICKUP
    EN_ROUTE_TO_PICKUP --> AT_PICKUP_SPOT : Geofence Triggered (<30m) or Manual Tap
    AT_PICKUP_SPOT --> FREE_WAITING : Timer Starts (0 to 180s)
    FREE_WAITING --> PAID_WAITING : Elapsed > 180s ($0.45/min added to fare)

    FREE_WAITING --> OTP_VERIFIED : Driver enters 4-digit rider OTP
    PAID_WAITING --> OTP_VERIFIED : Driver enters 4-digit rider OTP

    PAID_WAITING --> NO_SHOW_CANCELLED : Wait > 300s & Driver taps No-Show

    OTP_VERIFIED --> TRIP_STARTED : Driver executes "SLIDE TO START TRIP"
    TRIP_STARTED --> [*] : Transition to SCR-DRV-004 (Turn-by-Turn Navigation)
```

---

## 3. Communication Contract (API & WebSocket)

### 3.1 Verify OTP & Start Trip Request (`POST /api/v1/rides/{rideId}/start`)

```json
{
  "ride_id": "ride_77218",
  "driver_id": "drv_9921",
  "otp_code": "4912",
  "pickup_timestamp": "2026-08-16T14:18:45Z",
  "location": {
    "latitude": 37.78971,
    "longitude": -122.40012,
    "accuracy_meters": 4.2
  },
  "wait_duration_seconds": 195,
  "accrued_wait_fare": 0.45
}
```

### 3.2 Success Response (200 OK)

```json
{
  "status": "IN_TRANSIT",
  "ride_id": "ride_77218",
  "trip_start_time": "2026-08-16T14:18:46Z",
  "destination": {
    "address": "San Francisco International Airport, Terminal 2",
    "latitude": 37.6188,
    "longitude": -122.3754
  },
  "navigation_route_polyline": "u{~nFv_hgVw@`Ac@p..."
}
```
