# Screen Contract: Passenger Route & Tariff Selection (`SCR-RIDER-002`)

This contract defines the client-side interaction, geocoding autocomplete, multi-stop route configuration, tariff selection carousel, dynamic surge multipliers, and upfront fare quote locking.

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

> [!NOTE]
> **Vector UI Wireframe:** View the standalone vector screen mockup: [passenger-route-selection.svg](../wireframes/passenger-route-selection.svg) ([.puml source](../wireframes/passenger-route-selection.puml)).

```mermaid
flowchart TB
    subgraph PhoneFrame ["📱 Smartphone Viewport · Passenger App (SCR-RIDER-002)"]
        direction TB

        subgraph TopBar ["Layer 1: Top Address & Route Bar (Floating Island)"]
            A["📍 [A] Pickup: 555 Market St, San Francisco"]
            B["🏁 [B] Dropoff: SFO Airport Terminal 2"]
            AddStop["➕ Add Intermediate Stop (+1)"]
        end

        subgraph MapCanvas ["Layer 0: Full-Screen 3D Vector Map Viewport"]
            Route["🗺️ Route Polyline: 24 min · 11.4 km (No traffic delays)"]
        end

        subgraph BottomSheet ["Layer 2: Sliding Bottom Sheet (Swipe Up / Down)"]
            direction TB
            subgraph Tariffs ["Horizontal Tariff Selection Carousel (Swipe ◄ ►)"]
                T1["🚗 <b>Economy</b><br/><b>$18.50</b><br/>⚡ 1.3x Surge<br/>3 min ETA"]
                T2["✨ <b>Comfort</b><br/><b>$24.00</b><br/>Extra Legroom<br/>5 min ETA"]
                T3["💼 <b>Business</b><br/><b>$38.00</b><br/>Executive Sedan<br/>8 min ETA"]
                T4["🚐 <b>XL Group</b><br/><b>$46.50</b><br/>6-Seater SUV<br/>6 min ETA"]
            end

            subgraph PayRow ["Payment Method & Discounts"]
                Pay["💳 Visa •••• 4242 (Change)"]
                Promo["🏷️ Promo: SUMMER2026 (-$5.00)"]
                Options["⚙️ Ride Options (Child Seat)"]
            end

            CTA["🔵 <b>CONFIRM & BOOK ECONOMY · $18.50</b> (Quote Locked: 118s)"]
        end
    end

    style PhoneFrame fill:#F8FAFC,stroke:#334155,stroke-width:3px
    style TopBar fill:#FFFFFF,stroke:#94A3B8,stroke-width:2px
    style MapCanvas fill:#E0F2FE,stroke:#0284C7,stroke-width:2px
    style BottomSheet fill:#FFFFFF,stroke:#64748B,stroke-width:2px
    style T1 fill:#EFF6FF,stroke:#2563EB,stroke-width:2px
    style T2 fill:#F8FAFC,stroke:#CBD5E1,stroke-width:1px
    style T3 fill:#F8FAFC,stroke:#CBD5E1,stroke-width:1px
    style T4 fill:#F8FAFC,stroke:#CBD5E1,stroke-width:1px
    style CTA fill:#2563EB,stroke:#1D4ED8,color:#FFFFFF,stroke-width:2px
```

### 1.1 Bottom Sheet Dynamics & Expansion Heights

The bottom sheet utilizes a 3-tier gesture-driven spring animation:

| Height Tier                 | Pixel Height            | Visible Elements                                                                                          | User Trigger                                |
| --------------------------- | ----------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------- |
| **Collapsed**               | $160\text{ dp}$         | Active tariff name, price ($18.50), Surge pill, and Primary CTA button.                                   | Default map exploration mode.               |
| **Half-Expanded (Default)** | $380\text{ dp}$         | Full tariff carousel, payment selector, promo code chip, and CTA button.                                  | Upon route calculation response.            |
| **Fully Expanded**          | $100\%\text{ Viewport}$ | Full address input overlay, saved places (Home/Work), and advanced ride options (Child seat, quiet ride). | Tapping origin or destination input fields. |


---

## 2. Client State Machine & Invariants

```mermaid
stateDiagram-v2
    [*] --> ADDRESS_INPUT : Screen Opened
    ADDRESS_INPUT --> GEOCODING_SEARCH : User types in search query
    GEOCODING_SEARCH --> ROUTE_CALCULATING : Destination Selected
    ROUTE_CALCULATING --> TARIFFS_LOADED : POST /api/v1/pricing/quote (200 OK)

    TARIFFS_LOADED --> TARIFF_CHANGED : User swipes carousel
    TARIFF_CHANGED --> TARIFFS_LOADED : Active Tariff Updated

    TARIFFS_LOADED --> QUOTE_EXPIRED : Timer > 120s elapsed
    QUOTE_EXPIRED --> ROUTE_CALCULATING : Auto-Refresh Quote

    TARIFFS_LOADED --> REQUESTING_RIDE : User taps "Book Ride"
    REQUESTING_RIDE --> [*] : Transition to SCR-RIDER-005 (Radar Search)
```

---

## 3. Communication Contracts & Payloads

### 3.1 Upfront Quote Request (`POST /api/v1/pricing/quote`)

```json
{
  "passenger_id": "usr_88192a",
  "waypoints": [
    {
      "sequence": 0,
      "address": "555 Market St, San Francisco, CA",
      "latitude": 37.7897,
      "longitude": -122.4001,
      "type": "PICKUP"
    },
    {
      "sequence": 1,
      "address": "San Francisco International Airport (SFO)",
      "latitude": 37.6188,
      "longitude": -122.3754,
      "type": "DROPOFF"
    }
  ],
  "client_timestamp": "2026-08-16T14:00:00Z"
}
```

### 3.2 Quote Response with Cryptographic Lock

```json
{
  "quote_id": "qte_99381b10a",
  "expires_at": "2026-08-16T14:02:00Z",
  "duration_seconds": 1440,
  "distance_meters": 21800,
  "route_polyline": "u{~nFv_hgVw@`Ac@p...",
  "tariffs": [
    {
      "category_id": "economy",
      "name": "Economy",
      "eta_pickup_minutes": 3,
      "fare_amount": 28.5,
      "currency": "USD",
      "surge_multiplier": 1.35,
      "surge_flat_bonus": 0.0,
      "is_surge_active": true,
      "quote_signature": "sha256:7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069"
    },
    {
      "category_id": "comfort",
      "name": "Comfort",
      "eta_pickup_minutes": 5,
      "fare_amount": 36.0,
      "currency": "USD",
      "surge_multiplier": 1.2,
      "surge_flat_bonus": 0.0,
      "is_surge_active": true,
      "quote_signature": "sha256:4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a"
    },
    {
      "category_id": "business",
      "name": "Business Executive",
      "eta_pickup_minutes": 8,
      "fare_amount": 58.0,
      "currency": "USD",
      "surge_multiplier": 1.0,
      "surge_flat_bonus": 0.0,
      "is_surge_active": false,
      "quote_signature": "sha256:ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d"
    }
  ]
}
```
