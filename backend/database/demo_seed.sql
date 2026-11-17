USE carlog_db;

-- Demo User
INSERT INTO users (id, email, password_hash, full_name, is_email_verified)
VALUES (
    'd0000000-0000-0000-0000-000000000001',
    'demo@carlog.xyz',
    '$2y$10$e7W74y/4o9/iH6sC51B6h.M3t9W2.YV7/Bq8uXzKk.fN1UoPz8sQ2',
    'Demo Driver',
    1
) ON DUPLICATE KEY UPDATE full_name = VALUES(full_name);

-- Demo Car: 2022 Toyota Corolla
INSERT INTO vehicles (
    id, user_id, vehicle_type, vin, plate_number, make, model, year,
    engine_displacement_cc, engine_code, power_kw, transmission_type, fuel_type,
    acquisition_odometer_km, current_odometer_km, public_share_token, hide_costs_on_share
) VALUES (
    'c0000000-0000-0000-0000-000000000001',
    'd0000000-0000-0000-0000-000000000001',
    'car',
    '2T1BURHE7NC123456',
    'B 789123',
    'TOYOTA',
    'COROLLA',
    2022,
    1798,
    '2ZR-FAE',
    103,
    'cvt',
    'gasoline',
    15,
    32450,
    'demo-corolla-2022',
    0
) ON DUPLICATE KEY UPDATE current_odometer_km = VALUES(current_odometer_km);

-- Quick Specs for Corolla
INSERT INTO vehicle_quick_specs (
    vehicle_id, oil_viscosity, oil_capacity_l, coolant_spec, coolant_capacity_l,
    front_tire_size, rear_tire_size, front_tire_pressure_bar, rear_tire_pressure_bar,
    wiper_driver_mm, wiper_passenger_mm, wiper_rear_mm, battery_spec,
    spark_plug_gap_mm, wheel_lug_torque_nm
) VALUES (
    'c0000000-0000-0000-0000-000000000001',
    '0W-20 Full Synthetic',
    4.20,
    'Toyota Super Long Life (Pink)',
    6.50,
    '205/55 R16',
    '205/55 R16',
    2.30,
    2.20,
    650,
    350,
    null,
    '12V 60Ah 540CCA (AGM)',
    1.10,
    103
) ON DUPLICATE KEY UPDATE oil_viscosity = VALUES(oil_viscosity);

-- Contact Workshop
INSERT INTO contacts_directory (
    id, user_id, shop_name, specialty, phone, location_notes
) VALUES (
    'w0000000-0000-0000-0000-000000000001',
    'd0000000-0000-0000-0000-000000000001',
    'Apex Auto Precision',
    'mechanic',
    '+96170123456',
    'Beirut Industrial Area, Bay 4'
) ON DUPLICATE KEY UPDATE shop_name = VALUES(shop_name);

-- Service Visits & Logs
INSERT INTO service_visits (
    id, vehicle_id, contact_id, service_date, odometer_km, visit_title, notes
) VALUES (
    'v0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    'w0000000-0000-0000-0000-000000000001',
    '2024-03-15',
    10120,
    '10,000 km Initial Factory Service',
    'Oil and filter change completed. 40-point safety inspection passed.'
), (
    'v0000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000001',
    'w0000000-0000-0000-0000-000000000001',
    '2024-09-20',
    20350,
    '20,000 km Scheduled Service & Filters',
    'Oil flush, engine air filter and cabin pollen filter replaced.'
), (
    'v0000000-0000-0000-0000-000000000003',
    'c0000000-0000-0000-0000-000000000001',
    'w0000000-0000-0000-0000-000000000001',
    '2025-05-10',
    30500,
    '30,000 km Brake Overhaul & Inspection',
    'Replaced front ceramic pads. Rotors measured 24.2mm (within spec).'
) ON DUPLICATE KEY UPDATE odometer_km = VALUES(odometer_km);

INSERT INTO maintenance_logs (
    id, visit_id, vehicle_id, task_id, contact_id, service_date, odometer_km,
    cost_parts_usd, cost_labor_usd, part_brand, part_number, fluid_volume_l,
    wheel_positions, measurement_mm, notes
) VALUES (
    'l0000000-0000-0000-0000-000000000001',
    'v0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'w0000000-0000-0000-0000-000000000001',
    '2024-03-15',
    10120,
    45.00,
    25.00,
    'Mann-Filter',
    'W 68/3',
    4.20,
    null,
    null,
    'OEM spec 0W-20 Toyota Genuine Motor Oil'
), (
    'l0000000-0000-0000-0000-000000000002',
    'v0000000-0000-0000-0000-000000000002',
    'c0000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000010',
    'w0000000-0000-0000-0000-000000000001',
    '2024-09-20',
    20350,
    28.00,
    15.00,
    'Denso',
    '17801-0T060',
    null,
    null,
    null,
    'Replaced engine air intake filter'
), (
    'l0000000-0000-0000-0000-000000000003',
    'v0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000020',
    'w0000000-0000-0000-0000-000000000001',
    '2025-05-10',
    30500,
    85.00,
    45.00,
    'Brembo',
    'P 83 150',
    null,
    'FL,FR',
    9.5,
    'Low-dust ceramic front brake pads. Bedding procedure performed.'
) ON DUPLICATE KEY UPDATE odometer_km = VALUES(odometer_km);
