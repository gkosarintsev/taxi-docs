# ADR-0002: Uber H3 Hexagonal Spatial Index for Geospatial Indexing & Surge Pricing

- **Status:** Accepted
- **Deciders:** Geospatial Lead Engineer, Matching Engine Architect, Principal Data Scientist
- **Date:** 2026-01-20
- **Technical Story:** GEO-CORE-002 (Discrete Global Grid System Selection)

---

## Context and Problem Statement

The platform requires high-frequency spatial operations:

1. Identifying nearby candidate drivers within a variable search radius ($R \approx 1\text{ km} - 5\text{ km}$) for ride dispatch.
2. Grouping supply and demand into discrete geometric cells to compute dynamic surge pricing multipliers in real time.
3. Aggregating heatmaps and route telemetry for dispatch analytics.

Traditional geospatial queries using Euclidean distance or R-Tree indices (e.g. standard PostGIS `ST_DWithin`) become severe bottlenecks under 50,000+ driver coordinate updates/sec and concurrent search queries. We require a Discrete Global Grid System (DGGS) that enables integer-based constant time indexing ($O(1)$) and uniform neighbor distance calculation.

---

## Decision Drivers

- **Uniform Neighbor Distances:** All neighboring cells must share identical centroid-to-centroid distances to avoid directional bias.
- **Hierarchical Resolution:** Ability to aggregate data upwards (e.g. from street block to neighborhood to city level) without geometric distortions.
- **Computational Efficiency:** Point-to-cell indexing and neighbor lookups (`kRing` expansion) must be fast integer operations executable in-memory in microseconds ($< 5\mu s$).
- **Memory Footprint:** Efficient 64-bit integer representation (`uint64`) suitable for Redis cache keys and BitSet lookups.

---

## Considered Options

1. **Uber H3 (Hexagonal Hierarchical Spatial Index)**
2. **Google S2 (Spherical Quadrilateral Quadtree System)**
3. **Geohash (Base32 Rectangular Grid System)**
4. **Raw PostGIS Post-Tree / R-Tree In-Memory Indexes**

---

## Decision Outcome

Chosen option: **Uber H3 (Hexagonal Hierarchical Spatial Index)**.

### Rationale

- **Hexagon Equidistance Property:** Hexagons have 6 neighbors, and every neighbor centroid is strictly equidistant. In contrast, squares/rectangles (Geohash and S2) have 8 neighbors with two distinct distance classes ($1$ for orthogonal neighbors, $\sqrt{2} \approx 1.414$ for diagonal neighbors). This prevents artifact distortions during radius searches and driver discovery.
- **Hierarchical Nesting:** H3 provides 16 discrete resolution levels (from global resolution 0 down to sub-meter resolution 15).
- **Surge Pricing Aggregation:** H3 Resolution 7 and 8 provide optimal spatial granularity for dynamic surge pricing (cell area: $\sim 1.2\text{ km}^2$ to $\sim 0.7\text{ km}^2$).
- **Compact 64-bit Hash:** Every H3 cell is represented as a native `uint64` (or 15-character hex string), allowing ultra-fast BitSet operations and Redis Set/Hash lookups.

---

## Resolution Mapping for System Features

| Feature Domain                  | H3 Resolution | Avg Hexagon Area    | Avg Edge Length | System Purpose                                   |
| :------------------------------ | :------------ | :------------------ | :-------------- | :----------------------------------------------- |
| **City Level Surge Bounds**     | Resolution 6  | $36.1\text{ km}^2$  | $3.7\text{ km}$ | Macro demand analysis & regional fleet balancing |
| **Dynamic Surge Pricing**       | Resolution 7  | $5.16\text{ km}^2$  | $1.4\text{ km}$ | Local surge multiplier calculation               |
| **Driver Discovery & Dispatch** | Resolution 8  | $0.73\text{ km}^2$  | $461\text{ m}$  | `kRing(1..3)` driver search radius               |
| **Pickup Point Clustering**     | Resolution 10 | $0.015\text{ km}^2$ | $65\text{ m}$   | Safe pickup/dropoff zone snapping                |

---

## Technical Validation

```go
// Example Go H3 Neighbor Lookup Benchmark (Sub-microsecond)
func GetCandidateDrivers(pickupLat, pickupLon float64, searchRadiusRings int) []h3.Cell {
    originCell := h3.LatLngToCell(h3.LatLng{Lat: pickupLat, Lng: pickupLon}, 8)
    return originCell.GridDisk(searchRadiusRings) // Returns 1 + 6*k ring cells in < 2 microseconds
}
```
