# UI Component Specifications & Interaction Rules

This document outlines the standard UI component catalog, interactive behaviors, states, and design token bindings for client applications.

---

## 1. Core Component Catalog

### 1.1 `RideCard` (Tariff Selection Widget)

- **Visuals:** Rounded card ($16\text{px}$ radius), 1px subtle border (`#E2E8F0` / dark: `#1E293B`).
- **States:**
  - `Default`: Subtle background, vehicle tier icon, title, estimated arrival time, price.
  - `Selected`: 2px `#2563EB` border, elevated shadow (`box-shadow: 0 4px 14px rgba(37, 99, 235, 0.15)`).
  - `SurgeActive`: Includes flame badge (`🔥 1.3x Surge`) in `#EA580C`.

### 1.2 `DriverRadarHUD` (Floating Active Tracking Pill)

- **Visuals:** Glassmorphic pill (`backdrop-filter: blur(12px)`), dark/light adaptive.
- **Content:** Driver thumbnail ($48\times 48\text{px}$ circle), name, rating star, license plate badge with monospace font (`JetBrains Mono`), dynamic ETA badge.
- **Interactions:** Tap opens full bottom sheet with driver contact options, share ride link, and cancellation policy.

### 1.3 `OfferCountdownModal` (Driver 15s Offer HUD)

- **Visuals:** High-urgency overlay with radial SVG progress bar ($15\text{s} \to 0\text{s}$).
- **Color Progression:** Starts Green (`#16A34A`), shifts to Yellow (`#CA8A04`) at 7s, turns Red (`#DC2626`) at 3s.
- **Haptics:** Heavy haptic bump at trigger, rapid ticking during last 3 seconds.

### 1.4 `FloatingActionPill` (SOS & Quick Safety Actions)

- **Visuals:** High-contrast pill anchored at top-right of map view.
- **SOS Button:** Crimson red fill (`#DC2626`), white shield icon.
- **Action:** Hold for 2 seconds (prevents accidental taps) to initiate emergency dispatch workflow.

---

## 2. Micro-Animations & Motion Design

| Component / Action                  | Animation Type                                  | Duration                 | Easing Curve                       |
| :---------------------------------- | :---------------------------------------------- | :----------------------- | :--------------------------------- |
| **Radar Ripple Pulse**              | Concentric scale ($0.8 \to 2.2$) + opacity fade | $2.4\text{s}$ (infinite) | `cubic-bezier(0.2, 0.8, 0.2, 1.0)` |
| **Bottom Sheet Expand/Collapse**    | Vertical translation ($\Delta Y$)               | $320\text{ms}$           | `cubic-bezier(0.32, 0.72, 0, 1)`   |
| **Vehicle Marker Bearing Rotation** | Angular interpolation ($\Delta \theta$)         | $400\text{ms}$           | `linear`                           |
| **Price Surge Badge Flash**         | Pulse scale ($1.0 \to 1.08 \to 1.0$)            | $600\text{ms}$           | `ease-in-out`                      |
