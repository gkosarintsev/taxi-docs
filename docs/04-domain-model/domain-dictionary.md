# Domain Dictionary (Ubiquitous Language)

This glossary standardizes the core terms, domain entities, and operational concepts used across engineering, product design, and business documentation.

---

## 1. Core Domain Entities

| Term                               | Ubiquitous Definition                                                                                                                         | System Code Representation             |
| :--------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------- |
| **Passenger (Rider)**              | An authenticated customer who requests, books, rides, and pays for on-demand or scheduled trips.                                              | `User(role="PASSENGER")`               |
| **Driver Partner**                 | A licensed independent contractor or fleet-employed driver who operates a vehicle and fulfills ride dispatches.                               | `DriverProfile`, `User(role="DRIVER")` |
| **B2B Tenant (Corporate / Fleet)** | An enterprise legal entity managing corporate travel allowances or owning a fleet pool of vehicles.                                           | `TenantB2B`                            |
| **Ride (Trip)**                    | A single transport contract between a Passenger and a Driver from origin pickup stop(s) to destination drop-off stop(s).                      | `Ride`                                 |
| **Ride Stop**                      | A specific geocoded stop point within a ride itinerary (Pickup, Intermediate Waypoint, or Final Dropoff).                                     | `RideStop`                             |
| **Vehicle**                        | A motorized passenger car registered on the platform with verified license plates, safety inspections, and tariff classification.             | `Vehicle`                              |
| **Tariff Class**                   | The service tier determining pricing parameters, vehicle luxury level, and passenger capacity (e.g. _Economy_, _Comfort_, _Business_, _Van_). | `TariffClass` (Enum)                   |

---

## 2. Geospatial & Operational Concepts

| Term                        | Ubiquitous Definition                                                                                                                             |
| :-------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------ |
| **H3 Index**                | A 64-bit integer identifier representing a discrete hexagonal geographic cell within Uber's H3 hierarchical spatial grid system.                  |
| **kRing (Grid Disk)**       | An expanding concentric set of hexagonal neighboring cells around an origin H3 cell (e.g. $k=1$ is 6 immediate neighbors, $k=2$ is 18 neighbors). |
| **Map Matching (Snapping)** | Algorithmic alignment of raw noisy GPS coordinates from mobile sensors to the underlying OpenStreetMap road segment network geometry.             |
| **Deadheading**             | Miles driven or time spent by a driver with an empty vehicle while waiting for an offer or traveling to a passenger pickup point.                 |
| **Geofence**                | A virtual geographic boundary (e.g. airport terminals, stadium pick-up zones, municipal boundaries) triggering specific rules or surcharges.      |

---

## 3. Financial & Dispatch Concepts

| Term                                | Ubiquitous Definition                                                                                                                                  |
| :---------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Dynamic Surge Pricing**           | Real-time algorithmic multiplier applied to the base fare when local passenger demand significantly exceeds available driver supply within an H3 cell. |
| **Quote Freeze Token**              | A cryptographically signed, short-lived (120s) token locking the estimated ride fare during the passenger checkout flow.                               |
| **Pre-Authorization Hold**          | A temporary credit/debit card hold reserved through the PSP prior to dispatch to ensure passenger solvency.                                            |
| **Double-Entry Ledger**             | An accounting system where every transaction must record equal and opposite debit and credit entries ($\sum \text{Debits} + \sum \text{Credits} = 0$). |
| **Dispatch Offer Ringing**          | The 15-second timed exclusive window presented to a candidate driver to accept a proposed trip assignment.                                             |
| **Take Rate (Platform Commission)** | The percentage fee deducted by the platform from the gross trip fare prior to accruing net driver earnings (typically $15\% - 25\%$).                  |
