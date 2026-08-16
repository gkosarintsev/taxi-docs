-- ============================================================================
-- Urban Mobility Platform: Core Relational Database DDL Schema
-- Engine: PostgreSQL 15+ (with PostGIS and B-Tree GiST Extensions)
-- File: 001_core_schema.sql
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- ============================================================================
-- 1. ENUMS AND DOMAINS
-- ============================================================================

CREATE TYPE user_role_enum AS ENUM ('PASSENGER', 'DRIVER', 'DISPATCHER', 'ADMIN', 'SYSTEM');
CREATE TYPE tariff_class_enum AS ENUM ('ECONOMY', 'COMFORT', 'BUSINESS', 'VAN', 'CARPOOL');
CREATE TYPE ride_status_enum AS ENUM (
    'DRAFT', 'SEARCHING', 'OFFERED', 'ALLOCATED', 
    'ARRIVED_PICKUP', 'IN_PROGRESS', 'DROPOFF_ARRIVED', 
    'COMPLETED', 'CANCELLED_BY_RIDER', 'CANCELLED_BY_DRIVER', 'EXPIRED'
);
CREATE TYPE driver_shift_status_enum AS ENUM ('OFFLINE', 'ONLINE_SEARCHING', 'OFFER_RECEIVED', 'ON_TRIP', 'REST_BREAK');
CREATE TYPE kyc_status_enum AS ENUM ('PENDING', 'DOCUMENTS_SUBMITTED', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'SUSPENDED');
CREATE TYPE stop_type_enum AS ENUM ('PICKUP', 'WAYPOINT', 'DROPOFF');

-- ============================================================================
-- 2. TENANTS & CORPORATE CLIENTS
-- ============================================================================

CREATE TABLE tenants_b2b (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(128) NOT NULL,
    tax_id VARCHAR(64) NOT NULL UNIQUE,
    credit_limit NUMERIC(12, 2) NOT NULL DEFAULT 0.00 CHECK (credit_limit >= 0),
    current_balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    billing_email VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

CREATE INDEX idx_tenants_tax_id ON tenants_b2b(tax_id);

-- ============================================================================
-- 3. USERS & PASSENGER ACCOUNTS
-- ============================================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number VARCHAR(32) NOT NULL UNIQUE,
    email VARCHAR(255),
    full_name VARCHAR(128) NOT NULL,
    role user_role_enum NOT NULL DEFAULT 'PASSENGER',
    rating_avg NUMERIC(3, 2) NOT NULL DEFAULT 5.00 CHECK (rating_avg BETWEEN 1.00 AND 5.00),
    rating_count INTEGER NOT NULL DEFAULT 0 CHECK (rating_count >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    tenant_id UUID REFERENCES tenants_b2b(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_users_tenant ON users(tenant_id) WHERE tenant_id IS NOT NULL;

-- ============================================================================
-- 4. VEHICLES & FLEET MANAGEMENT
-- ============================================================================

CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID REFERENCES tenants_b2b(id) ON DELETE SET NULL,
    license_plate VARCHAR(32) NOT NULL UNIQUE,
    make VARCHAR(64) NOT NULL,
    model VARCHAR(64) NOT NULL,
    year_manufactured INTEGER NOT NULL CHECK (year_manufactured BETWEEN 2000 AND 2035),
    color VARCHAR(32) NOT NULL,
    tariff_class tariff_class_enum NOT NULL DEFAULT 'ECONOMY',
    passenger_seats SMALLINT NOT NULL DEFAULT 4 CHECK (passenger_seats BETWEEN 1 AND 8),
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

CREATE INDEX idx_vehicles_license_plate ON vehicles(license_plate);
CREATE INDEX idx_vehicles_tariff_verified ON vehicles(tariff_class, is_verified);

-- ============================================================================
-- 5. DRIVER PROFILES
-- ============================================================================

CREATE TABLE driver_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    license_number VARCHAR(64) NOT NULL UNIQUE,
    kyc_status kyc_status_enum NOT NULL DEFAULT 'PENDING',
    payout_account_id VARCHAR(128),
    current_vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    shift_status driver_shift_status_enum NOT NULL DEFAULT 'OFFLINE',
    acceptance_rate NUMERIC(5, 2) NOT NULL DEFAULT 100.00 CHECK (acceptance_rate BETWEEN 0.00 AND 100.00),
    cancellation_rate NUMERIC(5, 2) NOT NULL DEFAULT 0.00 CHECK (cancellation_rate BETWEEN 0.00 AND 100.00),
    current_h3_res8 VARCHAR(15),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

CREATE INDEX idx_drivers_shift_status ON driver_profiles(shift_status) WHERE shift_status != 'OFFLINE';
CREATE INDEX idx_drivers_h3_spatial ON driver_profiles(current_h3_res8) WHERE current_h3_res8 IS NOT NULL;

-- ============================================================================
-- 6. GEOFENCES & TARIFF ZONES (POSTGIS)
-- ============================================================================

CREATE TABLE geofence_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_name VARCHAR(64) NOT NULL,
    polygon_geom GEOMETRY(Polygon, 4326) NOT NULL,
    is_airport_zone BOOLEAN NOT NULL DEFAULT FALSE,
    surcharge_amount NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

CREATE INDEX idx_geofence_spatial_gist ON geofence_zones USING GIST (polygon_geom);

-- ============================================================================
-- 7. RIDES & ORDERS
-- ============================================================================

CREATE TABLE rides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    passenger_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    driver_id UUID REFERENCES driver_profiles(id) ON DELETE SET NULL,
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    tenant_id UUID REFERENCES tenants_b2b(id) ON DELETE SET NULL,
    status ride_status_enum NOT NULL DEFAULT 'DRAFT',
    tariff_class tariff_class_enum NOT NULL,
    surge_multiplier NUMERIC(4, 2) NOT NULL DEFAULT 1.00 CHECK (surge_multiplier BETWEEN 1.00 AND 5.00),
    estimated_fare NUMERIC(10, 2) NOT NULL CHECK (estimated_fare >= 0),
    final_fare NUMERIC(10, 2) CHECK (final_fare >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    payment_method_id UUID,
    psp_hold_id VARCHAR(128),
    pickup_h3_res8 VARCHAR(15) NOT NULL,
    dropoff_h3_res8 VARCHAR(15) NOT NULL,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP()
);

-- Indices for Ride Queries
CREATE INDEX idx_rides_active_status ON rides(status, driver_id) 
    WHERE status IN ('SEARCHING', 'OFFERED', 'ALLOCATED', 'ARRIVED_PICKUP', 'IN_PROGRESS');

CREATE INDEX idx_rides_passenger_history ON rides(passenger_id, created_at DESC);
CREATE INDEX idx_rides_driver_history ON rides(driver_id, created_at DESC) WHERE driver_id IS NOT NULL;
CREATE INDEX idx_rides_h3_pickup ON rides(pickup_h3_res8);

-- BRIN index on created_at for high-throughput append-only time-series filtering
CREATE INDEX idx_rides_created_at_brin ON rides USING BRIN (created_at);

-- ============================================================================
-- 8. RIDE STOPS (MULTI-STOP & CARPOOLING)
-- ============================================================================

CREATE TABLE ride_stops (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    stop_sequence SMALLINT NOT NULL CHECK (stop_sequence >= 1),
    stop_type stop_type_enum NOT NULL,
    location_point GEOMETRY(Point, 4326) NOT NULL,
    h3_res8_index VARCHAR(15) NOT NULL,
    address_text TEXT NOT NULL,
    planned_eta TIMESTAMPTZ,
    actual_arrived_at TIMESTAMPTZ,
    passenger_otp_code VARCHAR(6),
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_ride_stop_sequence UNIQUE (ride_id, stop_sequence)
);

CREATE INDEX idx_ride_stops_location_gist ON ride_stops USING GIST (location_point);
CREATE INDEX idx_ride_stops_ride_id ON ride_stops(ride_id);

-- ============================================================================
-- 9. RIDE REVIEWS & FEEDBACK
-- ============================================================================

CREATE TABLE ride_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ride_id UUID NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    recipient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    score SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5),
    feedback_tags VARCHAR(64)[] DEFAULT '{}',
    comment_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CLOCK_TIMESTAMP(),
    CONSTRAINT uq_ride_author_review UNIQUE (ride_id, author_user_id)
);

CREATE INDEX idx_reviews_recipient ON ride_reviews(recipient_user_id, created_at DESC);

-- ============================================================================
-- 10. AUTOMATIC UPDATED_AT TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION update_timestamp_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CLOCK_TIMESTAMP();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_vehicles_updated_at BEFORE UPDATE ON vehicles FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_drivers_updated_at BEFORE UPDATE ON driver_profiles FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_rides_updated_at BEFORE UPDATE ON rides FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trg_tenants_updated_at BEFORE UPDATE ON tenants_b2b FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
