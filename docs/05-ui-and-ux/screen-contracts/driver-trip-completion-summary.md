# Screen Contract: Driver Trip Completion & Earnings Summary (`SCR-DRV-005`)

This contract defines the driver terminal behavior upon arriving at the destination, including the `SLIDE TO COMPLETE TRIP` gesture, the transparent fare breakdown receipt, instant tip notifications, rider rating submission, and seamless transition back to the dispatch queue.

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

```mermaid
flowchart TB
    subgraph TerminalFrame ["📱 Driver Mobile Terminal · Trip Completion & Receipt (SCR-DRV-005)"]
        direction TB

        subgraph TopBanner ["Layer 1: Destination Arrival Header"]
            ArrivedDestination["🏁 <b>Arrived at SFO Airport Terminal 2</b> · Dropoff Complete"]
        end

        subgraph NetEarningsCard ["Layer 2: Net Earnings Hero Card"]
            NetCash["💵 <size:18><b>+$29.80 Net Earnings</b></size><br/><i>Auto-credited to your instant driver wallet</i>"]
            TipAlert["🎁 <b>+$5.00 Tip Added by Sarah!</b> (100% to you)"]
        end

        subgraph BreakdownAccordion ["Layer 3: Itemized Fare Breakdown Receipt"]
            Base["Base Fare: $4.50 · Distance & Time: $24.50"]
            Surge["⚡ Surge 1.2x: +$5.80 · 🌉 Toll Reimbursement: +$6.50"]
            PlatformFee["Platform Commission (20%): -$7.15 · Paid Wait: +$0.45"]
        end

        subgraph RiderRatingSection ["Layer 4: Passenger Rating & Feedback"]
            RateStars["⭐ ⭐ ⭐ ⭐ ⭐ · [Rate Sarah K.]"]
            PositiveTags["✓ Polite · ✓ On-time at pickup · ✓ Respectful"]
        end

        NextRideCTA["🟩 <b>READY FOR NEXT RIDE (RETURN ONLINE)</b>"]
    end

    style TerminalFrame fill:#F8FAFC,stroke:#1E293B,stroke-width:3px
    style TopBanner fill:#ECFDF5,stroke:#059669,stroke-width:2px
    style NetEarningsCard fill:#EFF6FF,stroke:#2563EB,stroke-width:2px
    style TipAlert fill:#FEF3C7,stroke:#D97706,stroke-width:1px
    style BreakdownAccordion fill:#FFFFFF,stroke:#CBD5E1,stroke-width:1px
    style RiderRatingSection fill:#FFFFFF,stroke:#94A3B8,stroke-width:1px
    style NextRideCTA fill:#10B981,stroke:#047857,color:#FFFFFF,stroke-width:2px
```


### 1.1 `Slide to Complete Trip` Gesture

- Prevents premature trip completion while driving.
- Swipe right with tactile haptic confirmation triggers distance/fare aggregation and sends `COMPLETE_TRIP` to server.

### 1.2 Transparent Earnings Receipt Breakdown

- **Gross Fare:** $\$36.00$
  - Base Fare: $\$4.50$
  - Distance ($21.8\text{ km}$): $\$18.50$
  - Time ($24\text{ min}$): $\$6.00$
  - Dynamic Surge ($\times 1.2$): $+\$5.80$
  - Bridge Toll Reimbursement: $+\$6.50$ (100% passed to driver)
  - Paid Wait Time: $+\$0.45$
- **Platform Fee (20% on gross fare excl. tolls):** $-\$7.15$
- **Driver Net Trip Earnings:** **$\$29.80$**
- **Instant Tip Alert:** Real-time push modal when rider adds tip ($+\$5.00\text{ Tip} \rightarrow \text{Total: } \$34.80$).

### 1.3 Passenger Feedback Rating

- 5-Star interactive rating selector.
- Positive quick-tags: `Polite`, `On-time at pickup`, `Respectful`.
- Negative tags (if $\le 3$ stars): `Disrespectful`, `Left trash`, `Unsafe behavior`, `Door slam`.

---

## 2. State Machine & Event Flow

```mermaid
stateDiagram-v2
    [*] --> AT_DESTINATION : Distance to Dropoff < 30m
    AT_DESTINATION --> CALCULATING_FINAL_FARE : Driver executes "SLIDE TO COMPLETE TRIP"
    CALCULATING_FINAL_FARE --> SUMMARY_DISPLAYED : POST /api/v1/rides/{id}/complete (200 OK)

    SUMMARY_DISPLAYED --> TIP_RECEIVED_MODAL : WebSocket "RIDER_TIP_ADDED"
    TIP_RECEIVED_MODAL --> SUMMARY_DISPLAYED : Dismissed

    SUMMARY_DISPLAYED --> SUBMITTING_RATING : Driver selects stars & taps "Submit"
    SUBMITTING_RATING --> READY_FOR_DISPATCH : Rating recorded
    READY_FOR_DISPATCH --> [*] : Transition to SCR-DRV-001 (Online Radar)
```

---

## 3. Communication Contract (`POST /api/v1/rides/{rideId}/complete`)

```json
{
  "ride_id": "ride_77218",
  "driver_id": "drv_9921",
  "completion_timestamp": "2026-08-16T14:42:30Z",
  "final_location": {
    "latitude": 37.61882,
    "longitude": -122.37543,
    "accuracy_meters": 3.8
  },
  "odometer_distance_meters": 22100,
  "actual_duration_seconds": 1425,
  "tolls_incurred": [
    {
      "toll_name": "San Francisco-Oakland Bay Bridge",
      "amount": 6.5,
      "currency": "USD"
    }
  ]
}
```
