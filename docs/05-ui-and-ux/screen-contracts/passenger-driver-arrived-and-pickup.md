# Screen Contract: Passenger Driver Arrived & Pickup Spot (`SCR-RIDER-006`)

This specification defines the passenger-facing pickup HUD when the driver has arrived at the pickup location, displaying high-contrast vehicle identification, a 4-digit security OTP code, a free waiting countdown timer, and secure communication channels.

---

## 1. UI Components & Visual Layout

```mermaid
graph TD
    subgraph PickupHUD [Passenger Pickup Viewport]
        TopStatusBanner["'Driver Has Arrived!' Status Banner (Emerald Green #10B981)"]
        MapSpotCanvas["Vector Map Zoomed to Pickup Zone (Precision Pin + Driver Vehicle Marker)"]
        OTPBadge["4-Digit Security Pickup OTP Box ('Your Ride Code: 4 9 1 2')"]
        VehicleCard["Vehicle Identifier Card (High-Contrast Plate '7XYZ912' · Silver Toyota Camry)"]
        DriverProfile["Driver Avatar + Name ('Alex M. ★ 4.94 · 2,840 trips')"]
        WaitTimerHUD["Free Waiting Timer Bar ('Free wait: 2:15 remaining' -> 'Paid wait: $0.45/min')"]
        ActionCluster["Contact Shortcuts (In-App Chat · VoIP Masked Call · Safety Toolkit)"]
        CancelAction["'Cancel Ride' Action (Displays cancellation fee alert if >2 min)"]
    end
```

### 1.1 Vehicle Identification & Visual Contrast

- **High-Contrast Plate Banner:** Rendered in large bold font (`7XYZ912`) to allow immediate visual recognition in crowded curbside environments.
- **Car Visualizer:** Color badge (`Silver Metallic`) and 3D vehicle silhouette corresponding to the driver's registered vehicle.
- **Pickup Spot Walking Guide:** Dotted walking polyline with walking duration if passenger is $>30\text{ meters}$ away from vehicle pin.

### 1.2 4-Digit Security OTP

- To prevent riders from boarding the wrong vehicle, a large-format 4-digit code (`4 9 1 2`) is displayed in an elevated modal.
- Driver cannot start the trip on their terminal without entering or NFC-verifying this code.

### 1.3 Waiting Time & Pricing Indicator

- **Free Waiting Window (0:00 to 3:00 mins):** Circular countdown timer in Neutral Slate.
- **Paid Waiting Mode (> 3:00 mins):** Progress bar turns Amber (`#F59E0B`) displaying real-time accrued wait fees:
  $$\text{Wait Fee} = \max(0, t_{\text{elapsed}} - 180\text{ s}) \times \$0.45/\text{min}$$

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
