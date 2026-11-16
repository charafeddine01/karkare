-- =============================================================================
-- CarLog Database Schema (MariaDB 10.6+)
-- Platform: Offline-First Vehicle & Motorcycle Maintenance Platform
-- Currency: Strictly USD ($)
-- Units: Strictly Metric (km, L/mL, cc, kW, Nm, Bar, mm, kg, °C)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS carlog_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE carlog_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS diagnostic_symptoms;
DROP TABLE IF EXISTS fuel_logs;
DROP TABLE IF EXISTS maintenance_logs;
DROP TABLE IF EXISTS service_visits;
DROP TABLE IF EXISTS garage_inventory;
DROP TABLE IF EXISTS vehicle_quick_specs;
DROP TABLE IF EXISTS vehicle_part_catalog;
DROP TABLE IF EXISTS maintenance_tasks_template;
DROP TABLE IF EXISTS contacts_directory;
DROP TABLE IF EXISTS obd_codes_catalog;
DROP TABLE IF EXISTS vehicles;
DROP TABLE IF EXISTS users;
SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------------------------------
-- 1. Users Table
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    id CHAR(36) PRIMARY KEY,
    email VARCHAR(191) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NULL,
    google_sub_id VARCHAR(128) NULL UNIQUE,
    full_name VARCHAR(100) NOT NULL,
    is_email_verified TINYINT(1) NOT NULL DEFAULT 0,
    verification_code VARCHAR(6) NULL,
    verification_expires_at DATETIME NULL,
    created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 2. Vehicles Table
-- -----------------------------------------------------------------------------
CREATE TABLE vehicles (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36) NOT NULL,
    vehicle_type ENUM('car', 'motorcycle', 'truck') NOT NULL DEFAULT 'car',
    vin VARCHAR(17) NULL,
    plate_number VARCHAR(32) NULL,
    make VARCHAR(64) NOT NULL,
    model VARCHAR(64) NOT NULL,
    year SMALLINT UNSIGNED NOT NULL,
    engine_displacement_cc SMALLINT UNSIGNED NULL,
    engine_code VARCHAR(64) NULL,
    power_kw SMALLINT UNSIGNED NULL,
    transmission_type ENUM('manual', 'automatic', 'cvt', 'dct') NOT NULL DEFAULT 'manual',
    fuel_type ENUM('gasoline', 'diesel', 'hybrid', 'electric') NOT NULL DEFAULT 'gasoline',
    acquisition_odometer_km INT UNSIGNED NOT NULL DEFAULT 0,
    current_odometer_km INT UNSIGNED NOT NULL DEFAULT 0,
    photo_url VARCHAR(500) NULL,
    public_share_token VARCHAR(64) NULL UNIQUE,
    hide_costs_on_share TINYINT(1) NOT NULL DEFAULT 1,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_vehicle_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_updated (user_id, updated_at),
    INDEX idx_public_share (public_share_token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 3. Vehicle Quick Specs (Glovebox Reference Card)
-- -----------------------------------------------------------------------------
CREATE TABLE vehicle_quick_specs (
    vehicle_id CHAR(36) PRIMARY KEY,
    oil_viscosity VARCHAR(32) NULL,
    oil_capacity_l DECIMAL(4,2) NULL,
    coolant_spec VARCHAR(64) NULL,
    coolant_capacity_l DECIMAL(4,2) NULL,
    front_tire_size VARCHAR(32) NULL,
    rear_tire_size VARCHAR(32) NULL,
    front_tire_pressure_bar DECIMAL(3,2) NULL,
    rear_tire_pressure_bar DECIMAL(3,2) NULL,
    wiper_driver_mm SMALLINT UNSIGNED NULL,
    wiper_passenger_mm SMALLINT UNSIGNED NULL,
    wiper_rear_mm SMALLINT UNSIGNED NULL,
    battery_spec VARCHAR(64) NULL,
    spark_plug_gap_mm DECIMAL(3,2) NULL,
    wheel_lug_torque_nm SMALLINT UNSIGNED NULL,
    chain_pitch_mm VARCHAR(32) NULL,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_specs_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 4. Contacts Directory (Mechanics, Electricians, Tire Shops, Parts Stores)
-- -----------------------------------------------------------------------------
CREATE TABLE contacts_directory (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36) NOT NULL,
    shop_name VARCHAR(100) NOT NULL,
    specialty ENUM('mechanic', 'electrician', 'parts_store', 'tire_shop', 'body_shop', 'other') NOT NULL DEFAULT 'mechanic',
    phone VARCHAR(32) NULL,
    location_notes VARCHAR(255) NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_contact_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_contacts_user (user_id, is_deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 5. Maintenance Tasks Template (System & Custom User Templates)
-- -----------------------------------------------------------------------------
CREATE TABLE maintenance_tasks_template (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36) NULL, -- NULL = System Pre-Added Default
    category VARCHAR(64) NOT NULL,
    task_name VARCHAR(100) NOT NULL,
    applicable_to ENUM('all', 'car', 'motorcycle') NOT NULL DEFAULT 'all',
    default_interval_km INT UNSIGNED NULL,
    default_interval_months SMALLINT UNSIGNED NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_task_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_task_app (applicable_to, is_deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 6. Service Visits (Smart Service Bundles)
-- -----------------------------------------------------------------------------
CREATE TABLE service_visits (
    id CHAR(36) PRIMARY KEY,
    vehicle_id CHAR(36) NOT NULL,
    contact_id CHAR(36) NULL,
    service_date DATE NOT NULL,
    odometer_km INT UNSIGNED NOT NULL,
    visit_title VARCHAR(120) NULL,
    receipt_photo_url VARCHAR(500) NULL,
    notes TEXT NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_visit_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    CONSTRAINT fk_visit_contact FOREIGN KEY (contact_id) REFERENCES contacts_directory(id) ON DELETE SET NULL,
    INDEX idx_visit_vehicle_date (vehicle_id, service_date DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 7. Maintenance Logs (Individual Tasks in a Visit or Standalone)
-- -----------------------------------------------------------------------------
CREATE TABLE maintenance_logs (
    id CHAR(36) PRIMARY KEY,
    visit_id CHAR(36) NULL,
    vehicle_id CHAR(36) NOT NULL,
    task_id CHAR(36) NOT NULL,
    contact_id CHAR(36) NULL,
    service_date DATE NOT NULL,
    odometer_km INT UNSIGNED NOT NULL,
    cost_parts_usd DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    cost_labor_usd DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    total_cost_usd DECIMAL(10,2) GENERATED ALWAYS AS (cost_parts_usd + cost_labor_usd) STORED,
    part_brand VARCHAR(64) NULL,
    part_number VARCHAR(64) NULL,
    fluid_volume_l DECIMAL(5,2) NULL,
    wheel_positions VARCHAR(32) NULL, -- e.g. 'FL,FR', 'RL,RR', 'Spare', 'Front', 'Rear'
    tire_dot_code VARCHAR(16) NULL,
    measurement_mm DECIMAL(4,1) NULL, -- Tread depth or pad thickness in mm
    warranty_expires_date DATE NULL,
    notes TEXT NULL,
    receipt_photo_url VARCHAR(500) NULL,
    next_due_km INT UNSIGNED NULL,
    next_due_date DATE NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_log_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    CONSTRAINT fk_log_task FOREIGN KEY (task_id) REFERENCES maintenance_tasks_template(id),
    CONSTRAINT fk_log_visit FOREIGN KEY (visit_id) REFERENCES service_visits(id) ON DELETE CASCADE,
    CONSTRAINT fk_log_contact FOREIGN KEY (contact_id) REFERENCES contacts_directory(id) ON DELETE SET NULL,
    INDEX idx_vehicle_date (vehicle_id, service_date DESC),
    INDEX idx_task_vehicle (vehicle_id, task_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 8. Diagnostic Symptoms & OBD-II Journal
-- -----------------------------------------------------------------------------
CREATE TABLE diagnostic_symptoms (
    id CHAR(36) PRIMARY KEY,
    vehicle_id CHAR(36) NOT NULL,
    resolved_by_log_id CHAR(36) NULL,
    logged_date DATETIME NOT NULL,
    odometer_km INT UNSIGNED NOT NULL,
    obd_code VARCHAR(16) NULL,
    engine_state ENUM('cold_start', 'idle', 'acceleration', 'cruising', 'braking', 'other') NOT NULL DEFAULT 'other',
    symptom_description TEXT NOT NULL,
    audio_clip_url VARCHAR(500) NULL,
    is_resolved TINYINT(1) NOT NULL DEFAULT 0,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_symptom_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    CONSTRAINT fk_symptom_log FOREIGN KEY (resolved_by_log_id) REFERENCES maintenance_logs(id) ON DELETE SET NULL,
    INDEX idx_symptom_vehicle (vehicle_id, is_resolved, logged_date DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 9. Fuel Logs (Cost-Per-Kilometer & Efficiency Tracker)
-- -----------------------------------------------------------------------------
CREATE TABLE fuel_logs (
    id CHAR(36) PRIMARY KEY,
    vehicle_id CHAR(36) NOT NULL,
    fill_date DATETIME NOT NULL,
    odometer_km INT UNSIGNED NOT NULL,
    fuel_liters DECIMAL(6,2) NOT NULL,
    price_per_liter_usd DECIMAL(6,3) NOT NULL,
    total_cost_usd DECIMAL(10,2) NOT NULL,
    is_full_tank TINYINT(1) NOT NULL DEFAULT 1,
    calculated_l_per_100km DECIMAL(5,2) NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_fuel_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    INDEX idx_fuel_vehicle_date (vehicle_id, fill_date DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 10. Garage Inventory (Spare Parts Shelf)
-- -----------------------------------------------------------------------------
CREATE TABLE garage_inventory (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36) NOT NULL,
    vehicle_id CHAR(36) NULL,
    task_id CHAR(36) NULL,
    item_name VARCHAR(100) NOT NULL,
    part_brand VARCHAR(64) NULL,
    part_number VARCHAR(64) NULL,
    quantity DECIMAL(6,2) NOT NULL DEFAULT 1.00,
    unit_label ENUM('pcs', 'L', 'mL', 'set') NOT NULL DEFAULT 'pcs',
    purchase_price_usd DECIMAL(10,2) NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    CONSTRAINT fk_inv_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_inv_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE SET NULL,
    CONSTRAINT fk_inv_task FOREIGN KEY (task_id) REFERENCES maintenance_tasks_template(id) ON DELETE SET NULL,
    INDEX idx_inv_user (user_id, is_deleted)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 11. Vehicle Part Catalog (Crowdsourced 3-Tier Suggestion Engine)
-- -----------------------------------------------------------------------------
CREATE TABLE vehicle_part_catalog (
    id CHAR(36) PRIMARY KEY,
    make VARCHAR(64) NOT NULL,
    model VARCHAR(64) NOT NULL,
    year_start SMALLINT UNSIGNED NOT NULL,
    year_end SMALLINT UNSIGNED NOT NULL,
    engine_displacement_cc SMALLINT UNSIGNED NOT NULL,
    task_id CHAR(36) NOT NULL,
    part_brand VARCHAR(64) NOT NULL,
    part_number VARCHAR(64) NOT NULL,
    specs_note VARCHAR(255) NULL,
    usage_count INT UNSIGNED NOT NULL DEFAULT 1,
    verified_by_admin TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    UNIQUE KEY uk_fitment (make, model, year_start, engine_displacement_cc, task_id, part_number),
    INDEX idx_part_lookup (make, model, year_start, engine_displacement_cc, task_id),
    CONSTRAINT fk_catalog_task FOREIGN KEY (task_id) REFERENCES maintenance_tasks_template(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 12. OBD-II Codes Catalog
-- -----------------------------------------------------------------------------
CREATE TABLE obd_codes_catalog (
    code VARCHAR(16) PRIMARY KEY,
    category ENUM('powertrain', 'body', 'chassis', 'network') NOT NULL,
    description VARCHAR(255) NOT NULL,
    severity ENUM('low', 'medium', 'high', 'critical') NOT NULL DEFAULT 'medium'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 13. Trip Logs (KM & Purpose Tracking)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trip_logs (
    id VARCHAR(36) PRIMARY KEY,
    vehicle_id VARCHAR(36) NOT NULL,
    trip_date DATE NOT NULL,
    trip_time TIME NULL,
    start_odometer_km INT UNSIGNED NULL,
    end_odometer_km INT UNSIGNED NULL,
    distance_km DECIMAL(8,2) NOT NULL,
    purpose VARCHAR(50) NOT NULL DEFAULT 'Commute',
    notes TEXT NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    INDEX idx_trips_veh_date (vehicle_id, trip_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 14. General Vehicle Expenses (Parking, Tolls, Wash, Fines, Insurance)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS general_expenses (
    id VARCHAR(36) PRIMARY KEY,
    vehicle_id VARCHAR(36) NOT NULL,
    expense_date DATE NOT NULL,
    expense_time TIME NULL,
    expense_type VARCHAR(50) NOT NULL DEFAULT 'Parking',
    amount_usd DECIMAL(10,2) NOT NULL,
    odometer_km INT UNSIGNED NULL,
    notes TEXT NULL,
    receipt_photo_url VARCHAR(500) NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    INDEX idx_expenses_veh_date (vehicle_id, expense_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 15. Vehicle Reminders (Upcoming, Overdue, Completed with Dual Triggers)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicle_reminders (
    id VARCHAR(36) PRIMARY KEY,
    vehicle_id VARCHAR(36) NOT NULL,
    reminder_title VARCHAR(150) NOT NULL,
    reminder_category VARCHAR(50) NOT NULL DEFAULT 'Maintenance',
    due_date DATE NULL,
    due_odometer_km INT UNSIGNED NULL,
    is_completed TINYINT(1) NOT NULL DEFAULT 0,
    completed_date DATE NULL,
    notes TEXT NULL,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
    updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    INDEX idx_reminders_veh_status (vehicle_id, is_completed, due_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 16. MariaDB Trigger: trg_learn_part_number (Tier 3 Learning Trigger)
-- -----------------------------------------------------------------------------
DELIMITER $$
CREATE TRIGGER trg_learn_part_number
AFTER INSERT ON maintenance_logs
FOR EACH ROW
BEGIN
    DECLARE v_make VARCHAR(64);
    DECLARE v_model VARCHAR(64);
    DECLARE v_year SMALLINT UNSIGNED;
    DECLARE v_cc SMALLINT UNSIGNED;

    IF NEW.part_number IS NOT NULL AND TRIM(NEW.part_number) != '' AND NEW.is_deleted = 0 THEN
        SELECT make, model, year, COALESCE(engine_displacement_cc, 0)
        INTO v_make, v_model, v_year, v_cc
        FROM vehicles WHERE id = NEW.vehicle_id LIMIT 1;

        IF v_make IS NOT NULL THEN
            INSERT INTO vehicle_part_catalog (
                id, make, model, year_start, year_end,
                engine_displacement_cc, task_id, part_brand, part_number
            ) VALUES (
                UUID(), v_make, v_model, v_year, v_year,
                v_cc, NEW.task_id, COALESCE(NEW.part_brand, 'OEM / Generic'), TRIM(UPPER(NEW.part_number))
            )
            ON DUPLICATE KEY UPDATE
                usage_count = usage_count + 1,
                updated_at = CURRENT_TIMESTAMP(3);
        END IF;
    END IF;
END$$
DELIMITER ;
