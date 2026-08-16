-- ============================================================================
-- Urban Mobility Platform: High-Throughput Telemetry & Spatial Analytics OLAP
-- Engine: ClickHouse 23+ (MergeTree, ReplacingMergeTree, SummingMergeTree)
-- File: 003_clickhouse_telemetry_schema.sql
-- ============================================================================

CREATE DATABASE IF NOT EXISTS telemetry_analytics;

-- ============================================================================
-- 1. RAW HIGH-FREQUENCY DRIVER TELEMETRY (1-5 Hz STREAM)
-- Ingest rate: 100,000+ pings/second via Kafka ClickHouse Sink
-- ============================================================================

CREATE TABLE IF NOT EXISTS telemetry_analytics.driver_telemetry_raw (
    city_id LowCardinality(String),
    h3_res7 String,
    h3_res8 String,
    driver_id UUID,
    vehicle_id String,
    status LowCardinality(String),
    latitude Float64,
    longitude Float64,
    bearing Float32,
    speed_kph Float32,
    accuracy_meters Float32,
    hdop Float32,
    sat_count UInt8,
    event_time DateTime64(3, 'UTC'),
    ingested_at DateTime DEFAULT now()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_time)
ORDER BY (city_id, h3_res7, driver_id, event_time)
SETTINGS index_granularity = 8192
TTL event_time + INTERVAL 90 DAY;

-- ============================================================================
-- 2. TRIP TRAJECTORIES (MAP-SNAPPED & FILTERED FOR ACTIVE RIDES)
-- Used for dispute audit, speed profile extraction, and digital receipt maps
-- ============================================================================

CREATE TABLE IF NOT EXISTS telemetry_analytics.trip_trajectories (
    ride_id UUID,
    point_time DateTime64(3, 'UTC'),
    latitude Float64,
    longitude Float64,
    snapped_latitude Float64,
    snapped_longitude Float64,
    osm_way_id UInt64,
    bearing Float32,
    speed_kph Float32,
    altitude_meters Float32,
    is_snapped UInt8,
    viterbi_confidence Float32,
    version UInt32
) ENGINE = ReplacingMergeTree(version)
PARTITION BY toYYYYMM(point_time)
ORDER BY (ride_id, point_time)
SETTINGS index_granularity = 8192
TTL point_time + INTERVAL 365 DAY;

-- ============================================================================
-- 3. SAFETY INCIDENTS HIGH-RES TELEMETRY (50 Hz CRASH & ANOMALY BLACKBOX)
-- Captured during emergency triggers and accelerometer impacts > 4.0g
-- ============================================================================

CREATE TABLE IF NOT EXISTS telemetry_analytics.safety_incidents_telemetry (
    incident_id UUID,
    ride_id UUID,
    driver_id UUID,
    sample_time DateTime64(3, 'UTC'),
    accel_x Float32,
    accel_y Float32,
    accel_z Float32,
    total_g_force Float32,
    gyro_yaw_rate Float32,
    latitude Float64,
    longitude Float64,
    speed_kph Float32,
    trigger_type LowCardinality(String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(sample_time)
ORDER BY (incident_id, sample_time)
SETTINGS index_granularity = 2048
TTL sample_time + INTERVAL 1095 DAY; -- 3 Years Legal Evidentiary Retention

-- ============================================================================
-- 4. AGGREGATED HOURLY H3 SUPPLY-DEMAND STATS (MATERIALIZED VIEW TARGET)
-- ============================================================================

CREATE TABLE IF NOT EXISTS telemetry_analytics.hourly_h3_demand_stats (
    metric_hour DateTime,
    city_id LowCardinality(String),
    h3_res7 String,
    tariff_class LowCardinality(String),
    total_searches UInt64,
    total_orders_placed UInt64,
    total_orders_completed UInt64,
    avg_surge_multiplier Float32,
    avg_driver_count Float32,
    avg_pickup_eta_sec Float32,
    gross_bookings_amount Float64
) ENGINE = SummingMergeTree((
    total_searches, 
    total_orders_placed, 
    total_orders_completed, 
    gross_bookings_amount
))
PARTITION BY toYYYYMM(metric_hour)
ORDER BY (city_id, h3_res7, tariff_class, metric_hour)
TTL metric_hour + INTERVAL 730 DAY;
