-- =============================================================================
-- CarLog Database Seed Data
-- Seed: Maintenance Tasks Template, OBD-II Codes Catalog, Sample Fitment Catalog
-- =============================================================================

USE carlog_db;

-- -----------------------------------------------------------------------------
-- 1. Pre-Added Categorized Maintenance Tasks
-- -----------------------------------------------------------------------------
INSERT INTO maintenance_tasks_template (id, user_id, category, task_name, applicable_to, default_interval_km, default_interval_months, updated_at) VALUES
-- Engine & Fluids
('10000000-0000-0000-0000-000000000001', NULL, 'Engine & Fluids', 'Engine Oil & Filter', 'all', 10000, 12, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000002', NULL, 'Engine & Fluids', 'Coolant Flush & Top-up', 'all', 40000, 24, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000003', NULL, 'Engine & Fluids', 'Transmission Fluid Service', 'all', 60000, 36, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000004', NULL, 'Engine & Fluids', 'Brake Fluid Flush', 'all', 30000, 24, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000005', NULL, 'Engine & Fluids', 'Power Steering Fluid', 'car', 50000, 36, CURRENT_TIMESTAMP(3)),

-- Filters & Ignition
('10000000-0000-0000-0000-000000000010', NULL, 'Filters & Ignition', 'Engine Air Filter', 'all', 20000, 12, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000011', NULL, 'Filters & Ignition', 'Cabin A/C Pollen Filter', 'car', 20000, 12, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000012', NULL, 'Filters & Ignition', 'Fuel Filter', 'all', 40000, 24, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000013', NULL, 'Filters & Ignition', 'Spark Plugs Replacement', 'all', 40000, 36, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000014', NULL, 'Filters & Ignition', 'Ignition Coils', 'all', 80000, 48, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000015', NULL, 'Filters & Ignition', 'Timing Belt & Tensioner Kit', 'all', 100000, 60, CURRENT_TIMESTAMP(3)),

-- Brakes & Suspension
('10000000-0000-0000-0000-000000000020', NULL, 'Brakes & Suspension', 'Brake Pads (Front/Rear)', 'all', 30000, 24, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000021', NULL, 'Brakes & Suspension', 'Brake Rotors / Discs', 'all', 60000, 48, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000022', NULL, 'Brakes & Suspension', 'Shock Absorbers / Struts', 'all', 80000, 60, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000023', NULL, 'Brakes & Suspension', 'Control Arms & Bushings', 'car', 80000, 60, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000024', NULL, 'Brakes & Suspension', 'Tie Rods & Sway Bar Links', 'car', 80000, 60, CURRENT_TIMESTAMP(3)),

-- Tires & Wheels
('10000000-0000-0000-0000-000000000030', NULL, 'Tires & Wheels', 'Tire Replacement', 'all', 50000, 48, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000031', NULL, 'Tires & Wheels', 'Tire Rotation', 'car', 10000, 6, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000032', NULL, 'Tires & Wheels', 'Wheel Balancing', 'all', 15000, 12, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000033', NULL, 'Tires & Wheels', 'Wheel Alignment', 'car', 20000, 12, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000034', NULL, 'Tires & Wheels', 'Tire Puncture Repair', 'all', NULL, NULL, CURRENT_TIMESTAMP(3)),

-- Electrical & Battery
('10000000-0000-0000-0000-000000000040', NULL, 'Electrical & Battery', '12V Battery Replacement', 'all', 60000, 36, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000041', NULL, 'Electrical & Battery', 'Alternator Inspection / Repair', 'all', 100000, 60, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000042', NULL, 'Electrical & Battery', 'Starter Motor Service', 'all', 120000, 72, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000043', NULL, 'Electrical & Battery', 'Fuses & Relays Replacement', 'all', NULL, NULL, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000044', NULL, 'Electrical & Battery', 'Exterior & Interior Bulbs', 'all', NULL, NULL, CURRENT_TIMESTAMP(3)),

-- Cooling & HVAC
('10000000-0000-0000-0000-000000000050', NULL, 'Cooling & HVAC', 'Radiator Flush & Cleaning', 'all', 80000, 48, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000051', NULL, 'Cooling & HVAC', 'Thermostat Replacement', 'all', 80000, 48, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000052', NULL, 'Cooling & HVAC', 'Water Pump Replacement', 'all', 100000, 60, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000053', NULL, 'Cooling & HVAC', 'Heater Core Flush', 'car', 120000, 72, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000054', NULL, 'Cooling & HVAC', 'A/C Refrigerant Recharge', 'car', 40000, 24, CURRENT_TIMESTAMP(3)),

-- Exhaust & Drivetrain
('10000000-0000-0000-0000-000000000060', NULL, 'Exhaust & Drivetrain', 'Clutch Kit Replacement', 'all', 100000, 60, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000061', NULL, 'Exhaust & Drivetrain', 'CV Joints & Axle Boots', 'car', 100000, 60, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000062', NULL, 'Exhaust & Drivetrain', 'Exhaust Muffler / DB Killer', 'all', 100000, 60, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000063', NULL, 'Exhaust & Drivetrain', 'Oxygen (O2) Sensor', 'all', 80000, 48, CURRENT_TIMESTAMP(3)),

-- Motorcycle Specific
('10000000-0000-0000-0000-000000000070', NULL, 'Motorcycle Specific', 'Drive Chain Clean, Lube & Tension', 'motorcycle', 1000, 1, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000071', NULL, 'Motorcycle Specific', 'Chain & Sprocket Kit Replacement', 'motorcycle', 20000, 24, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000072', NULL, 'Motorcycle Specific', 'Fork Oil & Dust Seals', 'motorcycle', 20000, 24, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000073', NULL, 'Motorcycle Specific', 'Valve Clearance Check & Shims', 'motorcycle', 20000, 24, CURRENT_TIMESTAMP(3)),
('10000000-0000-0000-0000-000000000074', NULL, 'Motorcycle Specific', 'Throttle Body / Carburetor Sync', 'motorcycle', 15000, 18, CURRENT_TIMESTAMP(3))
ON DUPLICATE KEY UPDATE task_name = VALUES(task_name);

-- -----------------------------------------------------------------------------
-- 2. Common OBD-II Diagnostic Codes (Powertrain, Body, Chassis, Network)
-- -----------------------------------------------------------------------------
INSERT INTO obd_codes_catalog (code, category, description, severity) VALUES
('P0101', 'powertrain', 'Mass Air Flow (MAF) Circuit Range/Performance Problem', 'medium'),
('P0113', 'powertrain', 'Intake Air Temperature Sensor 1 Circuit High Input', 'low'),
('P0115', 'powertrain', 'Engine Coolant Temperature Circuit Malfunction', 'medium'),
('P0128', 'powertrain', 'Coolant Thermostat Temperature Below Regulating Temp', 'low'),
('P0130', 'powertrain', 'O2 Sensor Circuit Malfunction (Bank 1 Sensor 1)', 'medium'),
('P0133', 'powertrain', 'O2 Sensor Circuit Slow Response (Bank 1 Sensor 1)', 'low'),
('P0171', 'powertrain', 'System Too Lean (Bank 1)', 'medium'),
('P0172', 'powertrain', 'System Too Rich (Bank 1)', 'medium'),
('P0300', 'powertrain', 'Random/Multiple Cylinder Misfire Detected', 'high'),
('P0301', 'powertrain', 'Cylinder 1 Misfire Detected', 'high'),
('P0302', 'powertrain', 'Cylinder 2 Misfire Detected', 'high'),
('P0303', 'powertrain', 'Cylinder 3 Misfire Detected', 'high'),
('P0304', 'powertrain', 'Cylinder 4 Misfire Detected', 'high'),
('P0325', 'powertrain', 'Knock Sensor 1 Circuit Malfunction', 'medium'),
('P0340', 'powertrain', 'Camshaft Position Sensor Circuit Malfunction', 'high'),
('P0335', 'powertrain', 'Crankshaft Position Sensor A Circuit Malfunction', 'critical'),
('P0401', 'powertrain', 'Exhaust Gas Recirculation (EGR) Flow Insufficient', 'medium'),
('P0420', 'powertrain', 'Catalyst System Efficiency Below Threshold (Bank 1)', 'medium'),
('P0440', 'powertrain', 'Evaporative Emission Control System Malfunction', 'low'),
('P0442', 'powertrain', 'EVAP System Small Leak Detected', 'low'),
('P0455', 'powertrain', 'EVAP System Gross Leak / Gas Cap Loose', 'low'),
('P0500', 'powertrain', 'Vehicle Speed Sensor (VSS) Malfunction', 'high'),
('P0505', 'powertrain', 'Idle Air Control System Malfunction', 'medium'),
('P0700', 'powertrain', 'Transmission Control System (MIL Request)', 'high'),
('B0001', 'body', 'Driver Frontal Stage 1 Deployment Control', 'critical'),
('B0028', 'body', 'Right Side Airbag Deployment Control Circuit', 'critical'),
('B1000', 'body', 'ECU Electronic Control Unit Internal Fault', 'critical'),
('C0035', 'chassis', 'Left Front Wheel Speed Sensor Circuit', 'high'),
('C0040', 'chassis', 'Right Front Wheel Speed Sensor Circuit', 'high'),
('C0060', 'chassis', 'Left Front ABS Solenoid #1 Malfunction', 'high'),
('C0245', 'chassis', 'Wheel Speed Sensor Frequency Error', 'high'),
('U0001', 'network', 'High Speed CAN Communication Bus', 'critical'),
('U0100', 'network', 'Lost Communication With ECM/PCM A', 'critical'),
('U0101', 'network', 'Lost Communication with TCM', 'critical'),
('U0121', 'network', 'Lost Communication With Anti-Lock Brake System (ABS)', 'critical'),
('U0140', 'network', 'Lost Communication With Body Control Module (BCM)', 'high')
ON DUPLICATE KEY UPDATE description = VALUES(description);

-- -----------------------------------------------------------------------------
-- 3. Initial Crowdsourced Community Fitment Catalog (Tier 2 Part Suggestions)
-- -----------------------------------------------------------------------------
INSERT INTO vehicle_part_catalog (id, make, model, year_start, year_end, engine_displacement_cc, task_id, part_brand, part_number, specs_note, usage_count, verified_by_admin, updated_at) VALUES
('20000000-0000-0000-0000-000000000001', 'TOYOTA', 'COROLLA', 2018, 2024, 1798, '10000000-0000-0000-0000-000000000001', 'Mann-Filter', 'W 68/3', 'Spin-on oil filter (M19x1.5)', 42, 1, CURRENT_TIMESTAMP(3)),
('20000000-0000-0000-0000-000000000002', 'TOYOTA', 'COROLLA', 2018, 2024, 1798, '10000000-0000-0000-0000-000000000010', 'Denso', '17801-0T060', 'High flow OEM replacement air filter', 28, 1, CURRENT_TIMESTAMP(3)),
('20000000-0000-0000-0000-000000000003', 'TOYOTA', 'COROLLA', 2018, 2024, 1798, '10000000-0000-0000-0000-000000000020', 'Brembo', 'P 83 150', 'Front ceramic low-dust brake pads', 35, 1, CURRENT_TIMESTAMP(3)),
('20000000-0000-0000-0000-000000000004', 'HONDA', 'CIVIC', 2016, 2023, 1498, '10000000-0000-0000-0000-000000000001', 'Bosch', '3323', 'Premium FILTECH oil filter', 54, 1, CURRENT_TIMESTAMP(3)),
('20000000-0000-0000-0000-000000000005', 'HONDA', 'CIVIC', 2016, 2023, 1498, '10000000-0000-0000-0000-000000000013', 'NGK', 'ILZKAR8H8S', 'Laser Iridium spark plug', 39, 1, CURRENT_TIMESTAMP(3)),
('20000000-0000-0000-0000-000000000006', 'BMW', '3 SERIES', 2015, 2022, 1998, '10000000-0000-0000-0000-000000000001', 'Mahle', 'OX 813/2D', 'Eco oil filter element with O-rings', 61, 1, CURRENT_TIMESTAMP(3)),
('20000000-0000-0000-0000-000000000007', 'YAMAHA', 'MT-07', 2015, 2024, 689, '10000000-0000-0000-0000-000000000001', 'K&N', 'KN-204-1', 'Nutted wrench-off motorcycle filter', 77, 1, CURRENT_TIMESTAMP(3)),
('20000000-0000-0000-0000-000000000008', 'YAMAHA', 'MT-07', 2015, 2024, 689, '10000000-0000-0000-0000-000000000071', 'D.I.D', '525VX3-110L', 'X-Ring gold drive chain & JT sprockets', 48, 1, CURRENT_TIMESTAMP(3)),
('20000000-0000-0000-0000-000000000009', 'YAMAHA', 'MT-07', 2015, 2024, 689, '10000000-0000-0000-0000-000000000013', 'NGK', 'LMAR8A-9', 'Dual electrode standard plug', 51, 1, CURRENT_TIMESTAMP(3))
ON DUPLICATE KEY UPDATE usage_count = VALUES(usage_count);
