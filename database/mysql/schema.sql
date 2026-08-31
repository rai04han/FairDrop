-- FairDrop Pay Engine — MySQL Schema
-- Owner: Raihan
-- Database: MySQL 8.x
-- All monetary values in INR (Indian Rupees), stored as DECIMAL(10,2)

CREATE DATABASE IF NOT EXISTS fairdrop_pay;
USE fairdrop_pay;

-- ─────────────────────────────────────────────
-- riders
-- Minimal rider record for Pay Engine.
-- Full rider profile lives in Harikrishnan's MongoDB.
-- This table exists only to anchor foreign keys and store
-- pay-relevant state (cumulative earnings, active status).
-- ─────────────────────────────────────────────
CREATE TABLE riders (
    rider_id        VARCHAR(36)     NOT NULL,   -- matches rider_id from Auth module
    name            VARCHAR(100)    NOT NULL,
    phone           VARCHAR(15)     NOT NULL,
    zone_id         VARCHAR(50)     NOT NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (rider_id)
);

-- ─────────────────────────────────────────────
-- pay_configs
-- Admin-configurable pay constants.
-- Only one row should have is_active = TRUE at any time.
-- Historical configs are retained for audit.
-- 7-day advance notice policy: effective_from must be
-- at least 7 days after the config is created.
-- ─────────────────────────────────────────────
CREATE TABLE pay_configs (
    config_id           INT             NOT NULL AUTO_INCREMENT,
    base_rate           DECIMAL(10,2)   NOT NULL DEFAULT 15.00,
    per_km_rate         DECIMAL(10,2)   NOT NULL DEFAULT 6.00,
    surge_bonus         DECIMAL(10,2)   NOT NULL DEFAULT 20.00,
    wait_threshold_mins INT             NOT NULL DEFAULT 10,
    wait_compensation   DECIMAL(10,2)   NOT NULL DEFAULT 10.00,
    min_wage_per_hour   DECIMAL(10,2)   NOT NULL DEFAULT 70.00,
    effective_from      DATE            NOT NULL,
    is_active           BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by          VARCHAR(100)    NOT NULL,   -- admin user who set this config
    change_reason       TEXT            NOT NULL,   -- mandatory — supports 7-day notice policy
    PRIMARY KEY (config_id)
);

-- Seed: Kerala baseline defaults (active config)
INSERT INTO pay_configs (
    base_rate, per_km_rate, surge_bonus,
    wait_threshold_mins, wait_compensation, min_wage_per_hour,
    effective_from, is_active, created_by, change_reason
) VALUES (
    15.00, 6.00, 20.00,
    10, 10.00, 70.00,
    CURDATE(), TRUE, 'system', 'Initial Kerala baseline configuration'
);

-- ─────────────────────────────────────────────
-- deliveries
-- One row per completed delivery.
-- Immutable after insert — pay audit trail.
-- ─────────────────────────────────────────────
CREATE TABLE deliveries (
    delivery_id             INT             NOT NULL AUTO_INCREMENT,
    order_id                VARCHAR(30)     NOT NULL,   -- format: ORD-{YYYYMMDD}-{0000}
    rider_id                VARCHAR(36)     NOT NULL,
    config_id               INT             NOT NULL,   -- which pay config was active
    distance_km             DECIMAL(6,2)    NOT NULL,
    is_surge_active         BOOLEAN         NOT NULL DEFAULT FALSE,
    restaurant_wait_mins    INT             NOT NULL DEFAULT 0,
    active_hours_today      DECIMAL(5,2)    NOT NULL,
    delay_type              ENUM('traffic', 'restaurant', 'railway', 'none') NOT NULL DEFAULT 'none',
    delay_verified          BOOLEAN         NOT NULL DEFAULT FALSE,
    delay_source            ENUM('system_log', 'api_mock', 'none') NOT NULL DEFAULT 'none',
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (delivery_id),
    UNIQUE KEY uq_order_id (order_id),
    FOREIGN KEY (rider_id)   REFERENCES riders(rider_id),
    FOREIGN KEY (config_id)  REFERENCES pay_configs(config_id)
);

-- ─────────────────────────────────────────────
-- earnings
-- Computed pay breakdown per delivery.
-- One-to-one with deliveries.
-- Immutable after insert.
-- ─────────────────────────────────────────────
CREATE TABLE earnings (
    earning_id              INT             NOT NULL AUTO_INCREMENT,
    delivery_id             INT             NOT NULL,
    order_id                VARCHAR(30)     NOT NULL,
    rider_id                VARCHAR(36)     NOT NULL,
    base_rate               DECIMAL(10,2)   NOT NULL,
    distance_pay            DECIMAL(10,2)   NOT NULL,
    surge_bonus             DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    wait_compensation       DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    total_delivery_pay      DECIMAL(10,2)   NOT NULL,
    floor_topup             DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    hourly_earnings_so_far  DECIMAL(10,2)   NOT NULL,
    created_at              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (earning_id),
    UNIQUE KEY uq_delivery_id (delivery_id),
    FOREIGN KEY (delivery_id) REFERENCES deliveries(delivery_id),
    FOREIGN KEY (rider_id)    REFERENCES riders(rider_id)
);

-- ─────────────────────────────────────────────
-- Indexes for dashboard and analytics queries
-- ─────────────────────────────────────────────
CREATE INDEX idx_earnings_rider_date
    ON earnings (rider_id, created_at);

CREATE INDEX idx_deliveries_rider_date
    ON deliveries (rider_id, created_at);
