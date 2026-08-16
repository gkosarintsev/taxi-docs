# Screen Contract: Passenger Active Ride (`SCR-RIDER-006`)

This specification governs the live tracking, safety HUD, route rendering, and ETA streaming for an in-transit passenger.

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

```mermaid
flowchart TB
    subgraph PhoneFrame ["📱 Smartphone Viewport · Passenger Active Ride (SCR-RIDER-007)"]
        direction TB

        subgraph TopLiveETA ["Layer 1: Live Trip Progress Island (Floating)"]
            ETABadge["⏱️ <b>Arriving in 14 min</b> · 8.2 km · On-time (ETA 18:02)"]
            ShieldQuickBtn["🛡️ Safety Shield (SOS & Live Share)"]
        end

        subgraph MapLiveCanvas ["Layer 0: Full-Screen Live Map Canvas"]
            LiveCarTrack["🚗 Snapped Vehicle Cursor (60fps Cubic Spline) · Route Polyline with Live Traffic"]
            DestMarker["🏁 Destination Pin: SFO International Airport Terminal 2"]
        end

        subgraph BottomDriverSheet ["Layer 2: Driver Info & Trip Actions Sheet"]
            direction TB
            subgraph DriverCard ["Driver & Vehicle Info"]
                DriverMeta["👤 <b>Michael R.</b> ★ 4.94 · Silver Toyota Camry (7XYZ912)"]
                CommsRow["📞 Call Driver (Masked VoIP) · 💬 Message"]
            end

            subgraph SafetyActionRow ["In-Transit Safety & Controls"]
                ShareBtn["📲 <b>Share Live Tracking Link</b> (SMS / WhatsApp)"]
                EditDestBtn["✏️ Edit Destination / Add Stop"]
            end
        end
    end

    style PhoneFrame fill:#F8FAFC,stroke:#334155,stroke-width:3px
    style TopLiveETA fill:#0F172A,stroke:#38BDF8,color:#FFFFFF,stroke-width:2px
    style ETABadge fill:#0284C7,stroke:#0369A1,color:#FFFFFF,stroke-width:1px
    style ShieldQuickBtn fill:#0F172A,stroke:#10B981,color:#FFFFFF,stroke-width:1px
    style MapLiveCanvas fill:#E0F2FE,stroke:#0284C7,stroke-width:2px
    style BottomDriverSheet fill:#FFFFFF,stroke:#64748B,stroke-width:2px
    style DriverCard fill:#F8FAFC,stroke:#CBD5E1,stroke-width:1px
    style SafetyActionRow fill:#FFFFFF,stroke:#E2E8F0,stroke-width:1px
    style ShareBtn fill:#EFF6FF,stroke:#3B82F6,stroke-width:1px
    style EditDestBtn fill:#F8FAFC,stroke:#94A3B8,stroke-width:1px
```


---

## 2. Telemetry Ingestion & Interpolation Rules

1. **Dead Reckoning & Bezier Interpolation:**
   - Coordinate updates arrive every 1-2 seconds via WebSocket topic `rides.{rideId}.tracking`.
   - The client animates the vehicle marker using cubic Bezier spline interpolation to ensure 60fps smooth movement across network jitter.
2. **Geofence Proximity Trigger:**
   - When vehicle reaches $< 50\text{ meters}$ from pickup destination, client displays persistent notification and sound chime: `"Your driver has arrived"`.

---

## 3. Inbound WebSocket Event Contract: `RIDE_TELEMETRY_UPDATE`

```json
{
  "event": "RIDE_TELEMETRY_UPDATE",
  "ride_id": "ride_77218",
  "latitude": 37.776102,
  "longitude": -122.41829,
  "bearing": 94.0,
  "speed_kph": 38.4,
  "eta_remaining_seconds": 720,
  "distance_remaining_meters": 3400,
  "current_status": "IN_PROGRESS"
}
```
