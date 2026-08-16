# Screen Contract: B2B Dispatcher Monitoring Board (`SCR-B2B-001`)

This specification defines the multi-pane real-time web console used by enterprise dispatchers and fleet managers.

---

## 1. Visual Multi-Pane Web Console Architecture

```mermaid
flowchart TB
    subgraph WebBrowser ["🖥️ Desktop Web Browser · B2B Dispatcher Command Console (SCR-B2B-001)"]
        direction TB

        subgraph TopBar ["Layer 1: Enterprise Header & Global Fleet Filter Bar"]
            Header["🏢 <b>Acme Corp Fleet & Dispatch Operations</b> · Active Rides: <b>42</b> · Online Fleet: <b>128</b> · Total Spend Today: <b>$1,840.50</b>"]
        end

        subgraph SplitView ["Multi-Pane Dispatch View (Desktop Split-Screen)"]
            direction LR

            subgraph LeftGrid ["Active Trips Data Grid (45% Width)"]
                FilterRow["🔍 Search Employee / Driver / Cost Center · Status: [All ▼]"]
                Row1["🚗 <b>#CORP-9102</b> · Sarah K. (Marketing) ➔ SFO · Driver: Alex M. (7XYZ912) · <b>IN_TRANSIT (8 min)</b> · $34.20"]
                Row2["🚗 <b>#CORP-9103</b> · John D. (Sales) ➔ 555 Market · Driver: Elena V. · <b>ARRIVING (2 min)</b> · $18.50"]
                Row3["⏳ <b>#CORP-9104</b> · David P. (Engineering) · <b>MATCHING DRIVER...</b> · $24.00"]
            end

            subgraph RightMap ["Live Spatial Fleet & Route Map (55% Width)"]
                LiveMapCanvas["🗺️ <b>Real-Time Mapbox Vector Canvas</b><br/>Fleet Markers · Active Route Polylines · H3 Surge Overlay Toggle"]
                SelectedCard["📌 Selected Trip #CORP-9102: Speed 58 km/h · On-time · [Manual Re-assign] [Cancel]"]
            end
        end
    end

    style WebBrowser fill:#F8FAFC,stroke:#334155,stroke-width:3px
    style TopBar fill:#0F172A,stroke:#38BDF8,color:#FFFFFF,stroke-width:2px
    style SplitView fill:#FFFFFF,stroke:#CBD5E1,stroke-width:1px
    style LeftGrid fill:#F8FAFC,stroke:#94A3B8,stroke-width:1px
    style FilterRow fill:#FFFFFF,stroke:#E2E8F0,stroke-width:1px
    style Row1 fill:#EFF6FF,stroke:#3B82F6,stroke-width:1px
    style Row2 fill:#ECFDF5,stroke:#10B981,stroke-width:1px
    style Row3 fill:#FEF3C7,stroke:#F59E0B,stroke-width:1px
    style RightMap fill:#E0F2FE,stroke:#0284C7,stroke-width:1px
    style LiveMapCanvas fill:#0284C7,stroke:#0369A1,color:#FFFFFF,stroke-width:1px
    style SelectedCard fill:#FFFFFF,stroke:#334155,stroke-width:1px
```


---

## 2. Real-Time Synchronization Protocol

- **Connection:** Web browser establishes an SSE (Server-Sent Events) or WebSocket connection to:
  `wss://b2b.mobility-platform.io/v1/stream?tenant_id={tenant_id}&token={jwt}`
- **Delta Sync Invariant:**
  - Initial load fetches snapshot via `GET /api/v1/corporate/rides/active`.
  - Ongoing mutations arrive as incremental JSON patches (`OP: UPDATE`, `OP: INSERT`, `OP: DELETE`).

---

## 3. Real-Time Dispatch Event Payload

```json
{
  "op": "UPDATE",
  "booking_id": "CORP-9102",
  "status": "IN_TRANSIT",
  "driver_id": "drv_3381",
  "driver_name": "Alex Miller",
  "vehicle_plate": "7XYZ912",
  "eta_minutes": 8,
  "current_coordinates": {
    "lat": 37.7812,
    "lng": -122.411
  },
  "current_spend_amount": 34.2
}
```
