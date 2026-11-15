// =============================================================================
// CarLog Drift SQLite Local Database (Offline-First Source of Truth)
// Universal connection with drift_flutter (Native Android/iOS + WASM Web)
// =============================================================================

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

// -----------------------------------------------------------------------------
// 1. Table Definitions
// -----------------------------------------------------------------------------

class VehiclesTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get vehicleType => text().withDefault(const Constant('car'))();
  TextColumn get vin => text().nullable()();
  TextColumn get plateNumber => text().nullable()();
  TextColumn get make => text()();
  TextColumn get model => text()();
  IntColumn get year => integer()();
  IntColumn get engineDisplacementCc => integer().nullable()();
  TextColumn get engineCode => text().nullable()();
  IntColumn get powerKw => integer().nullable()();
  TextColumn get transmissionType => text().withDefault(const Constant('manual'))();
  TextColumn get fuelType => text().withDefault(const Constant('gasoline'))();
  IntColumn get acquisitionOdometerKm => integer().withDefault(const Constant(0))();
  IntColumn get currentOdometerKm => integer().withDefault(const Constant(0))();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get publicShareToken => text().nullable()();
  BoolColumn get hideCostsOnShare => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class VehicleQuickSpecsTable extends Table {
  TextColumn get vehicleId => text()();
  TextColumn get oilViscosity => text().nullable()();
  RealColumn get oilCapacityL => real().nullable()();
  TextColumn get coolantSpec => text().nullable()();
  RealColumn get coolantCapacityL => real().nullable()();
  TextColumn get frontTireSize => text().nullable()();
  TextColumn get rearTireSize => text().nullable()();
  RealColumn get frontTirePressureBar => real().nullable()();
  RealColumn get rearTirePressureBar => real().nullable()();
  IntColumn get wiperDriverMm => integer().nullable()();
  IntColumn get wiperPassengerMm => integer().nullable()();
  IntColumn get wiperRearMm => integer().nullable()();
  TextColumn get batterySpec => text().nullable()();
  RealColumn get sparkPlugGapMm => real().nullable()();
  IntColumn get wheelLugTorqueNm => integer().nullable()();
  TextColumn get chainPitchMm => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {vehicleId};
}

class ContactsDirectoryTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get shopName => text()();
  TextColumn get specialty => text().withDefault(const Constant('mechanic'))();
  TextColumn get phone => text().nullable()();
  TextColumn get locationNotes => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MaintenanceTasksTemplateTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()(); // NULL = system task
  TextColumn get category => text()();
  TextColumn get taskName => text()();
  TextColumn get applicableTo => text().withDefault(const Constant('all'))();
  IntColumn get defaultIntervalKm => integer().nullable()();
  IntColumn get defaultIntervalMonths => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ServiceVisitsTable extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  TextColumn get contactId => text().nullable()();
  DateTimeColumn get serviceDate => dateTime()();
  IntColumn get odometerKm => integer()();
  TextColumn get visitTitle => text().nullable()();
  TextColumn get receiptPhotoUrl => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MaintenanceLogsTable extends Table {
  TextColumn get id => text()();
  TextColumn get visitId => text().nullable()();
  TextColumn get vehicleId => text()();
  TextColumn get taskId => text()();
  TextColumn get contactId => text().nullable()();
  DateTimeColumn get serviceDate => dateTime()();
  IntColumn get odometerKm => integer()();
  RealColumn get costPartsUsd => real().withDefault(const Constant(0.0))();
  RealColumn get costLaborUsd => real().withDefault(const Constant(0.0))();
  TextColumn get partBrand => text().nullable()();
  TextColumn get partNumber => text().nullable()();
  RealColumn get fluidVolumeL => real().nullable()();
  TextColumn get wheelPositions => text().nullable()();
  TextColumn get tireDotCode => text().nullable()();
  RealColumn get measurementMm => real().nullable()();
  DateTimeColumn get warrantyExpiresDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptPhotoUrl => text().nullable()();
  IntColumn get nextDueKm => integer().nullable()();
  DateTimeColumn get nextDueDate => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DiagnosticSymptomsTable extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  TextColumn get resolvedByLogId => text().nullable()();
  DateTimeColumn get loggedDate => dateTime()();
  IntColumn get odometerKm => integer()();
  TextColumn get obdCode => text().nullable()();
  TextColumn get engineState => text().withDefault(const Constant('other'))();
  TextColumn get symptomDescription => text()();
  TextColumn get audioClipUrl => text().nullable()();
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class FuelLogsTable extends Table {
  TextColumn get id => text()();
  TextColumn get vehicleId => text()();
  DateTimeColumn get fillDate => dateTime()();
  IntColumn get odometerKm => integer()();
  RealColumn get fuelLiters => real()();
  RealColumn get pricePerLiterUsd => real()();
  RealColumn get totalCostUsd => real()();
  BoolColumn get isFullTank => boolean().withDefault(const Constant(true))();
  RealColumn get calculatedLPer100km => real().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class GarageInventoryTable extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get vehicleId => text().nullable()();
  TextColumn get taskId => text().nullable()();
  TextColumn get itemName => text()();
  TextColumn get partBrand => text().nullable()();
  TextColumn get partNumber => text().nullable()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unitLabel => text().withDefault(const Constant('pcs'))();
  RealColumn get purchasePriceUsd => real().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending_insert'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class VehiclePartCatalogTable extends Table {
  TextColumn get id => text()();
  TextColumn get make => text()();
  TextColumn get model => text()();
  IntColumn get yearStart => integer()();
  IntColumn get yearEnd => integer()();
  IntColumn get engineDisplacementCc => integer()();
  TextColumn get taskId => text()();
  TextColumn get partBrand => text()();
  TextColumn get partNumber => text()();
  TextColumn get specsNote => text().nullable()();
  IntColumn get usageCount => integer().withDefault(const Constant(1))();
  BoolColumn get verifiedByAdmin => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncMetaTable extends Table {
  TextColumn get metaKey => text()();
  TextColumn get metaValue => text()();

  @override
  Set<Column> get primaryKey => {metaKey};
}

// -----------------------------------------------------------------------------
// 2. Drift Database Class
// -----------------------------------------------------------------------------

@DriftDatabase(tables: [
  VehiclesTable,
  VehicleQuickSpecsTable,
  ContactsDirectoryTable,
  MaintenanceTasksTemplateTable,
  ServiceVisitsTable,
  MaintenanceLogsTable,
  DiagnosticSymptomsTable,
  FuelLogsTable,
  GarageInventoryTable,
  VehiclePartCatalogTable,
  SyncMetaTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'carlog_local_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        port: DriftWorkerOptions(
          Uri.parse('drift_worker.js'),
        ),
      ),
    );
  }

  /// Initial seed of maintenance task templates on database creation
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaultMaintenanceTasks();
    },
  );

  Future<void> _seedDefaultMaintenanceTasks() async {
    const uuid = Uuid();
    final now = DateTime.now().toUtc();

    final tasks = [
      // Engine & Fluids
      ('10000000-0000-0000-0000-000000000001', 'Engine & Fluids', 'Engine Oil & Filter', 'all', 10000, 12),
      ('10000000-0000-0000-0000-000000000002', 'Engine & Fluids', 'Coolant Flush & Top-up', 'all', 40000, 24),
      ('10000000-0000-0000-0000-000000000003', 'Engine & Fluids', 'Transmission Fluid Service', 'all', 60000, 36),
      ('10000000-0000-0000-0000-000000000004', 'Engine & Fluids', 'Brake Fluid Flush', 'all', 30000, 24),
      ('10000000-0000-0000-0000-000000000005', 'Engine & Fluids', 'Power Steering Fluid', 'car', 50000, 36),

      // Filters & Ignition
      ('10000000-0000-0000-0000-000000000010', 'Filters & Ignition', 'Engine Air Filter', 'all', 20000, 12),
      ('10000000-0000-0000-0000-000000000011', 'Filters & Ignition', 'Cabin A/C Pollen Filter', 'car', 20000, 12),
      ('10000000-0000-0000-0000-000000000012', 'Filters & Ignition', 'Fuel Filter', 'all', 40000, 24),
      ('10000000-0000-0000-0000-000000000013', 'Filters & Ignition', 'Spark Plugs Replacement', 'all', 40000, 36),
      ('10000000-0000-0000-0000-000000000014', 'Filters & Ignition', 'Ignition Coils', 'all', 80000, 48),
      ('10000000-0000-0000-0000-000000000015', 'Filters & Ignition', 'Timing Belt & Tensioner Kit', 'all', 100000, 60),

      // Brakes & Suspension
      ('10000000-0000-0000-0000-000000000020', 'Brakes & Suspension', 'Brake Pads (Front/Rear)', 'all', 30000, 24),
      ('10000000-0000-0000-0000-000000000021', 'Brakes & Suspension', 'Brake Rotors / Discs', 'all', 60000, 48),
      ('10000000-0000-0000-0000-000000000022', 'Brakes & Suspension', 'Shock Absorbers / Struts', 'all', 80000, 60),
      ('10000000-0000-0000-0000-000000000023', 'Brakes & Suspension', 'Control Arms & Bushings', 'car', 80000, 60),
      ('10000000-0000-0000-0000-000000000024', 'Brakes & Suspension', 'Tie Rods & Sway Bar Links', 'car', 80000, 60),

      // Tires & Wheels
      ('10000000-0000-0000-0000-000000000030', 'Tires & Wheels', 'Tire Replacement', 'all', 50000, 48),
      ('10000000-0000-0000-0000-000000000031', 'Tires & Wheels', 'Tire Rotation', 'car', 10000, 6),
      ('10000000-0000-0000-0000-000000000032', 'Tires & Wheels', 'Wheel Balancing', 'all', 15000, 12),
      ('10000000-0000-0000-0000-000000000033', 'Tires & Wheels', 'Wheel Alignment', 'car', 20000, 12),
      ('10000000-0000-0000-0000-000000000034', 'Tires & Wheels', 'Tire Puncture Repair', 'all', null, null),

      // Electrical & Battery
      ('10000000-0000-0000-0000-000000000040', 'Electrical & Battery', '12V Battery Replacement', 'all', 60000, 36),
      ('10000000-0000-0000-0000-000000000041', 'Electrical & Battery', 'Alternator Inspection / Repair', 'all', 100000, 60),
      ('10000000-0000-0000-0000-000000000042', 'Electrical & Battery', 'Starter Motor Service', 'all', 120000, 72),

      // Motorcycle Specific
      ('10000000-0000-0000-0000-000000000070', 'Motorcycle Specific', 'Drive Chain Clean, Lube & Tension', 'motorcycle', 1000, 1),
      ('10000000-0000-0000-0000-000000000071', 'Motorcycle Specific', 'Chain & Sprocket Kit Replacement', 'motorcycle', 20000, 24),
      ('10000000-0000-0000-0000-000000000072', 'Motorcycle Specific', 'Fork Oil & Dust Seals', 'motorcycle', 20000, 24),
      ('10000000-0000-0000-0000-000000000073', 'Motorcycle Specific', 'Valve Clearance Check & Shims', 'motorcycle', 20000, 24),
      ('10000000-0000-0000-0000-000000000074', 'Motorcycle Specific', 'Throttle Body / Carburetor Sync', 'motorcycle', 15000, 18),
    ];

    await batch((b) {
      for (final t in tasks) {
        b.insert(
          maintenanceTasksTemplateTable,
          MaintenanceTasksTemplateTableCompanion(
            id: Value(t.$1),
            userId: const Value(null),
            category: Value(t.$2),
            taskName: Value(t.$3),
            applicableTo: Value(t.$4),
            defaultIntervalKm: Value(t.$5),
            defaultIntervalMonths: Value(t.$6),
            isDeleted: const Value(false),
            syncStatus: const Value('synced'),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }
}
