# Screen Contract: B2B Employee Policy & Ride Booking (`SCR-B2B-003`)

This specification defines the corporate employee booking modal within the passenger app, enforcement of corporate travel policies, cost center assignment, budget limits, and automated corporate expense accounting.

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

```mermaid
flowchart TB
    subgraph PhoneFrame ["📱 Smartphone Viewport · Corporate Employee Booking (SCR-B2B-003)"]
        direction TB

        subgraph ProfileHeader ["Layer 1: Profile Toggle & Policy Status"]
            Profile["🏢 <b>Acme Corp Business Profile</b> · [Switch to Personal]"]
            PolicyBadge["🟢 <b>✓ Within Travel Policy</b> (Allowed 07:00-22:00 · Max $100)"]
        end

        subgraph AccountingFields ["Layer 2: Corporate Accounting & Expense Form"]
            CostCenter["📁 Cost Center: <b>Marketing - US West (#CC-491)</b> ▼"]
            ProjectCode["🏷️ Project Reference: <b>[ Q3-PROMO-CAMPAIGN ]</b>"]
            TripPurpose["📝 Expense Purpose: <b>[ Client Dinner at Salesforce Tower ]</b>"]
        end

        subgraph BillingInfo ["Layer 3: Direct Corporate Billing Card"]
            CardInfo["💳 Direct Invoicing to Acme Corp Corporate Ledger (Net 30)"]
        end

        ConfirmCTA["🔵 <b>BOOK ON BUSINESS ACCOUNT ($36.00)</b>"]
    end

    style PhoneFrame fill:#F8FAFC,stroke:#334155,stroke-width:3px
    style ProfileHeader fill:#FFFFFF,stroke:#94A3B8,stroke-width:1px
    style PolicyBadge fill:#ECFDF5,stroke:#059669,stroke-width:1px
    style AccountingFields fill:#EFF6FF,stroke:#3B82F6,stroke-width:2px
    style BillingInfo fill:#F8FAFC,stroke:#CBD5E1,stroke-width:1px
    style ConfirmCTA fill:#2563EB,stroke:#1D4ED8,color:#FFFFFF,stroke-width:2px
```


### 1.1 Policy Enforcement Invariants

- **Permitted Hours:** e.g., 07:00 AM – 10:00 PM on weekdays (or 24/7 if approved executive).
- **Geofencing:** Allowed origins/destinations within corporate branch office radius.
- **Maximum Fare Cap:** Auto-flags or requires manager pre-approval if single fare exceeds $\$100.00$.

---

## 2. Corporate Booking Request (`POST /api/v1/b2b/rides/create`)

```json
{
  "employee_user_id": "usr_emp_4412",
  "corporate_account_id": "corp_acme_9001",
  "cost_center_id": "cc_marketing_us_west",
  "project_reference": "Q3-PROMO-CAMPAIGN",
  "trip_purpose": "Client meeting at Salesforce Tower",
  "quote_id": "qte_99381b10a",
  "selected_tariff": "comfort"
}
```
