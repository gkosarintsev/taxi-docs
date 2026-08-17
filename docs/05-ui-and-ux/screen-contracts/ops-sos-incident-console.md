# Screen Contract: 24/7 Safety Operations SOC Emergency Console (`SCR-OPS-001`)

This contract defines the desktop/web operations console used by Safety Agents during critical SOS triggers, high-G collision detections, and severe safety escalations.

---

## 1. Visual Multi-Pane Desktop Console Layout

![SOC Emergency Console UI Schema](diagrams/ops-sos-incident-console.svg)

> _Source: [diagrams/ops-sos-incident-console.puml](diagrams/ops-sos-incident-console.puml)_


### 1.1 Live 10 Hz High-Frequency Telemetry

- Displays real-time speedometer, braking decel, yaw rate, and collision impact vector.
- Visual breadcrumb trace showing vehicle trajectory $60\text{ seconds}$ leading up to the trigger.

### 1.2 Instant Emergency Services Integration

- **PSAP (911 / 112) Direct Push:** One-click transmission of live cryptographic GPS tracking URL, vehicle make/model/plate, and rider name directly to municipal emergency dispatchers.
- **Automated Recording:** Cabin audio and VoIP call recording automatically preserved with AES-256 encryption for regulatory and legal evidence.

---

## 2. Emergency Escalation Payload (`POST /api/v1/ops/incidents/{id}/escalate-psap`)

```json
{
  "incident_id": "inc_sos_88192a",
  "ride_id": "ride_77218",
  "priority": "P0_CRITICAL",
  "psap_jurisdiction": "SFPD_EMERGENCY_SERVICES",
  "vehicle_snapshot": {
    "license_plate": "7XYZ912",
    "make_model": "Toyota Camry (Silver)",
    "current_coordinates": {
      "latitude": 37.78972,
      "longitude": -122.40015
    },
    "current_speed_kph": 0.0,
    "last_telemetry_timestamp": "2026-08-16T14:22:15Z"
  },
  "emergency_contacts_notified": true,
  "live_tracking_token_url": "https://safety.mobility.io/track/sos_token_77218_live"
}
```
