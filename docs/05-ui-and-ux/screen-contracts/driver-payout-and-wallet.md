# Screen Contract: Driver Wallet & Instant Payouts (`SCR-DRV-007`)

This specification defines the driver financial wallet screen, real-time balance tracking, weekly revenue bar charts, transaction ledgers, and the Instant Payout transfer workflow.

---

## 1. Visual UI Layout & Multi-Layer Hierarchy

```mermaid
flowchart TB
    subgraph TerminalFrame ["📱 Driver Mobile Terminal · Wallet & Instant Payouts (SCR-DRV-007)"]
        direction TB

        subgraph BalanceCard ["Layer 1: Available Balance & Cashout Hero"]
            CurrentBal["💵 <b>Available Balance: $342.10</b><br/><i>Auto-deposits free every Monday at 04:00 AM</i>"]
            CashoutCTA["🟩 <b>INSTANT CASHOUT TO DEBIT CARD ($341.60)</b><br/><i>Fast transfer in 1-2 minutes · $0.50 processing fee</i>"]
        end

        subgraph WeeklyChart ["Layer 2: 7-Day Revenue Analytics"]
            Bars["📊 Weekly Revenue: <b>$1,420.80</b> · 38.5 hrs online ($36.90/hr)<br/>Mon $180 · Tue $210 · Wed $240 · Thu $190 · Fri $310 · Sat $290.80"]
        end

        subgraph BreakdownPills ["Layer 3: Income Stream Breakdown"]
            IncomeFares["🚗 Fares: $1,120.00"]
            IncomeSurge["⚡ Surge: $165.00"]
            IncomeTips["🎁 Tips: $135.80 (100%)"]
        end

        subgraph PayoutMethod ["Layer 4: Linked Bank Account & Transactions"]
            LinkedCard["💳 Visa Debit •••• 9812 (Chase Bank · Instant Supported)"]
            LedgerList["📜 Recent History: Trip #77218 (+$29.80) · Instant Cashout (-$150.00)"]
        end
    end

    style TerminalFrame fill:#F8FAFC,stroke:#1E293B,stroke-width:3px
    style BalanceCard fill:#EFF6FF,stroke:#2563EB,stroke-width:2px
    style CashoutCTA fill:#10B981,stroke:#047857,color:#FFFFFF,stroke-width:2px
    style WeeklyChart fill:#FFFFFF,stroke:#CBD5E1,stroke-width:1px
    style BreakdownPills fill:#F8FAFC,stroke:#E2E8F0,stroke-width:1px
    style PayoutMethod fill:#FFFFFF,stroke:#94A3B8,stroke-width:1px
```


### 1.1 Balance & Instant Cashout

- **Available Balance:** Real-time net balance available for immediate withdrawal.
- **Instant Cashout Button:** Triggers real-time card push payment (via Stripe Custom / Adyen Payouts) with a flat $\$0.50$ processing fee.
- **Weekly Auto-Payout:** Un-withdrawn balances are automatically swept every Monday at 04:00 AM via ACH direct deposit free of charge.

### 1.2 Weekly Revenue Chart

- Interactive 7-day bar chart showing daily revenue, hours online, and net earnings per hour ($\$38.50/\text{hr}$).

---

## 2. Payout Request Contract (`POST /api/v1/payouts/instant`)

```json
{
  "driver_id": "drv_9921",
  "payout_amount": 342.1,
  "currency": "USD",
  "fee_amount": 0.5,
  "net_transfer_amount": 341.6,
  "destination_payment_method_id": "card_debit_9812",
  "idempotency_key": "pay_req_20260816_9921_001"
}
```
