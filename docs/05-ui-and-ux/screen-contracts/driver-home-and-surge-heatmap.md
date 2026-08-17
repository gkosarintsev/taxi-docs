# Screen Contract: Driver Home & Surge Heatmap (`SCR-DRV-001`)

This specification defines the primary idle dashboard for driver partners, including shift status management (Offline / Online), real-time H3 hexagonal Surge Heatmaps, shift earnings summaries, quest progression, and destination filtering ("Drive Towards Home").

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

> [!NOTE]
> **Vector UI Wireframe:** View the standalone vector screen mockup: [driver-home-dashboard.svg](../wireframes/driver-home-dashboard.svg) ([.puml source](../wireframes/driver-home-dashboard.puml)).

![Driver Home Dashboard UI Schema](diagrams/driver-home-and-surge-heatmap.svg)

> _Source: [diagrams/driver-home-and-surge-heatmap.puml](diagrams/driver-home-and-surge-heatmap.puml)_


### 1.1 Shift Online/Offline Toggle

- **Floating Status Pill:** High-contrast pill located at the top center.
  - **OFFLINE State:** Dark Gray (`#334155`), background map is dimmed. Tapping sends `DRIVER_SHIFT_ONLINE` event.
  - **ONLINE (WAITING FOR ORDERS):** Glowing Emerald Green (`#10B981`) with pulse animation and radar sweep.

### 1.2 H3 Hexagonal Surge Heatmap Layer

- Dynamically renders Uber H3 Resolution 7 hexagonal polygons over the map canvas.
- **Color Grading:**
  - $1.0\times - 1.2\times$: Transparent / Subtle blue outline.
  - $1.3\times - 1.6\times$: Yellow / Warm Amber (`#F59E0B`).
  - $1.7\times - 2.5\times+$: High-intensity Crimson Red (`#EF4444`) with flat bonus badge (`+$6.50`).
- Tapping any hexagon displays current demand volume, average ETA, and estimated surge bonus duration.

### 1.3 Destination Filter ("Driver Towards Home")

- Allows driver to set a preferred drop-off corridor (up to 2 times per day).
- Matching engine filters incoming dispatch offers to ensure marginal drop-off direction aligns with the specified destination ($\cos \theta \ge 0.70$).

---

## 2. Driver State Machine (Shift Lifecycle)

```mermaid
stateDiagram-v2
    [*] --> OFFLINE : App Launch
    OFFLINE --> GOING_ONLINE : Driver Taps "GO ONLINE"
    GOING_ONLINE --> ONLINE_IDLE : WebSocket Connected & GPS Telemetry Stream Active (1 Hz)

    ONLINE_IDLE --> OFFER_RINGING : Incoming Order Offer (SCR-DRV-002)
    OFFER_RINGING --> ONLINE_IDLE : Offer Declined / Timed Out (15s)
    OFFER_RINGING --> EN_ROUTE_PICKUP : Offer Accepted

    ONLINE_IDLE --> GOING_OFFLINE : Driver Taps "GO OFFLINE"
    GOING_OFFLINE --> OFFLINE : Shift Summary Stored
```

---

## 3. Communication Contract (WebSocket Surge Broadcast)

### Inbound Stream: `SURGE_HEATMAP_UPDATE`

```json
{
  "event": "SURGE_HEATMAP_UPDATE",
  "timestamp": "2026-08-16T14:20:00Z",
  "bounding_box": {
    "north": 37.812,
    "south": 37.701,
    "east": -122.35,
    "west": -122.52
  },
  "hexagons": [
    {
      "h3_index": "872830828ffffff",
      "surge_multiplier": 1.75,
      "surge_flat_bonus": 4.5,
      "demand_level": "VERY_HIGH"
    },
    {
      "h3_index": "87283082bffffff",
      "surge_multiplier": 1.3,
      "surge_flat_bonus": 0.0,
      "demand_level": "MODERATE"
    }
  ]
}
```
