# Screen Contract: Passenger Rating, Tipping & Split Fare (`SCR-PAS-006`)

This specification defines the post-trip settlement modal, 5-star interactive rating, driver tipping selector, feedback tag matrix, and split fare breakdown.

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

```mermaid
flowchart TB
    subgraph PhoneFrame ["📱 Smartphone Viewport · Post-Trip Rating & Tip (SCR-PAS-006)"]
        direction TB

        subgraph DriverSummary ["Layer 1: Driver & Fare Summary Header"]
            Avatar["👤 Michael B. ★ 4.94 · Silver Toyota Camry (7XYZ912)"]
            FareAmount["💳 <b>$24.50 Paid</b> via Apple Pay (Receipt Breakdown ▼)"]
        end

        subgraph StarRatingBox ["Layer 2: Interactive 5-Star Rating Bar"]
            Stars["⭐ ⭐ ⭐ ⭐ ⭐<br/><i>Tap to Rate Your Trip</i>"]
        end

        subgraph FeedbackTags ["Layer 3: Adaptive Feedback Chips"]
            Tags["✨ Pristine Car · 🛡️ Safe Driving · 🎵 Great Music · ⚡ Fast Route"]
        end

        subgraph TippingSection ["Layer 4: 100% Direct Driver Tip Chips"]
            direction LR
            Tip1["[$1.00]"]
            Tip2["[$3.00]"]
            Tip3["<b>[$5.00]</b>"]
            TipCustom["[Custom]"]
            TipZero["[No Tip]"]
        end

        subgraph SocialActions ["Layer 5: Split Fare & Favorites"]
            SplitBtn["👥 Split Fare with Friends (+2 Co-Riders: $8.17 ea)"]
            FavToggle["⭐ Add Michael to Favorite Drivers"]
        end

        SubmitCTA["🔵 <b>SUBMIT REVIEW & RECEIPT</b>"]
    end

    style PhoneFrame fill:#F8FAFC,stroke:#334155,stroke-width:3px
    style DriverSummary fill:#FFFFFF,stroke:#94A3B8,stroke-width:1px
    style StarRatingBox fill:#EFF6FF,stroke:#3B82F6,stroke-width:2px
    style FeedbackTags fill:#FFFFFF,stroke:#CBD5E1,stroke-width:1px
    style TippingSection fill:#FEF3C7,stroke:#D97706,stroke-width:1px
    style SocialActions fill:#F8FAFC,stroke:#E2E8F0,stroke-width:1px
    style SubmitCTA fill:#2563EB,stroke:#1D4ED8,color:#FFFFFF,stroke-width:2px
```


### 1.1 Header & Fare Summary

- **Driver Profile Pill:** Circular driver avatar with verified badge, vehicle make/model, and license plate.
- **Trip Receipt Summary:** Large header showing final charge (`$24.50`) with breakdown expander (Base fare `$18.00`, Surge `$3.50`, Tolls `$3.00`).

### 1.2 Interactive Rating & Adaptive Tag Matrix

- **5-Star Rating Bar:** Haptic-responsive star glyphs.
- **Adaptive Tags (Based on Star Score):**
  - **5 Stars (Compliments):** `✨ Pristine Car`, `🛡️ Safe Driving`, `🎵 Great Music`, `💬 Polite Conversation`, `⚡ Quick Route`.
  - **1–3 Stars (Constructive Complaints):** `⚠️ Reckless Driving`, `🚬 Car Odor`, `🛑 Unsafe Drop-off`, `📱 Phone Distraction`, `🗺️ Bad Route Choice`.

### 1.3 Driver Tipping Chips

- Fast one-tap tipping chips: `[$1.00]`, `[$3.00]`, `[$5.00]`, `[Custom]`, `[No Tip]`.
- Note: 100% of tips are disbursed directly to driver partner earnings ledger without platform commission.

### 1.4 Split Fare Drawer (Optional Sub-Flow)

- Allows rider to split invoice equally or proportionally among up to 4 registered phone contacts.
- Real-time indicator showing split shares (e.g. 3 riders $\to$ `$8.17` each).

---

## 2. Review & Tipping Submission Sequence

```mermaid
sequenceDiagram
    participant Rider as Passenger App
    participant Edge as Edge API Gateway
    participant Billing as Billing & Ledger Service
    participant Ratings as Rating & Feedback Service

    Rider->>Edge: POST /api/v1/rides/{rideId}/review {score: 5, tags: [...], tip_amount: 3.00}
    Edge->>Ratings: Record review & recalculate driver rolling average rating
    alt Tip Amount > 0
        Edge->>Billing: POST /api/v1/billing/ledger/tips {ride_id, amount: 3.00}
        Billing->>Billing: Charge rider payment method & credit driver wallet journal
    end
    Edge-->>Rider: 200 OK (Digital Receipt Archived)
    Rider->>Rider: Dismiss modal & return to main map
```

---

## 3. Screen Submission Contract Payload

```json
{
  "ride_id": "ride_88192a7",
  "score": 5,
  "feedback_tags": ["PRISTINE_CAR", "SAFE_DRIVING", "QUICK_ROUTE"],
  "comment": "Michael was courteous and took the express highway smoothly.",
  "tip": {
    "amount": 3.0,
    "currency": "USD",
    "payment_method_id": "pm_apple_pay_8819"
  },
  "is_favorite_driver_opt_in": true,
  "split_fare": {
    "is_split": true,
    "participants": [
      {
        "phone_number": "+14155551111",
        "share_amount": 13.75,
        "status": "ACCEPTED"
      },
      {
        "phone_number": "+14155552222",
        "share_amount": 13.75,
        "status": "PENDING"
      }
    ]
  }
}
```
