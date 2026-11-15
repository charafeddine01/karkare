// =============================================================================
// CarLog Vehicle DAO
// Handles Vehicles & Glovebox Quick-Specs CRUD with Drift SQLite
// =============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';

class VehicleDao {
  final AppDatabase db;
  static const _uuid = Uuid();

  VehicleDao(this.db);

  Stream<List<VehiclesTableData>> watchAllVehicles(String userId) {
    return (db.select(db.vehiclesTable)
          ..where((v) => v.userId.equals(userId) & v.isDeleted.equals(false))
          ..orderBy([(v) => OrderingTerm(expression: v.updatedAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<VehiclesTableData?> getVehicleById(String vehicleId) {
    return (db.select(db.vehiclesTable)..where((v) => v.id.equals(vehicleId))).getSingleOrNull();
  }

  Future<VehicleQuickSpecsTableData?> getQuickSpecs(String vehicleId) {
    return (db.select(db.vehicleQuickSpecsTable)..where((s) => s.vehicleId.equals(vehicleId))).getSingleOrNull();
  }

  Stream<VehicleQuickSpecsTableData?> watchQuickSpecs(String vehicleId) {
    return (db.select(db.vehicleQuickSpecsTable)..where((s) => s.vehicleId.equals(vehicleId))).watchSingleOrNull();
  }

  Future<String> upsertVehicle({
    String? id,
    required String userId,
    required String vehicleType,
    String? vin,
    String? plateNumber,
    required String make,
    required String model,
    required int year,
    int? displacementCc,
    String? engineCode,
    int? powerKw,
    String transmissionType = 'manual',
    String fuelType = 'gasoline',
    int acquisitionOdometerKm = 0,
    int currentOdometerKm = 0,
    String? photoUrl,
    String? publicShareToken,
    bool hideCostsOnShare = true,
  }) async {
    final vehicleId = id ?? _uuid.v4();
    final now = DateTime.now().toUtc();

    await db.into(db.vehiclesTable).insertOnConflictUpdate(
      VehiclesTableCompanion(
        id: Value(vehicleId),
        userId: Value(userId),
        vehicleType: Value(vehicleType),
        vin: Value(vin),
        plateNumber: Value(plateNumber),
        make: Value(make),
        model: Value(model),
        year: Value(year),
        engineDisplacementCc: Value(displacementCc),
        engineCode: Value(engineCode),
        powerKw: Value(powerKw),
        transmissionType: Value(transmissionType),
        fuelType: Value(fuelType),
        acquisitionOdometerKm: Value(acquisitionOdometerKm),
        currentOdometerKm: Value(currentOdometerKm),
        photoUrl: Value(photoUrl),
        publicShareToken: Value(publicShareToken),
        hideCostsOnShare: Value(hideCostsOnShare),
        isDeleted: const Value(false),
        syncStatus: const Value('pending_update'),
        updatedAt: Value(now),
      ),
    );

    return vehicleId;
  }

  Future<void> updateCurrentOdometer(String vehicleId, int newOdometerKm) async {
    final now = DateTime.now().toUtc();
    await (db.update(db.vehiclesTable)..where((v) => v.id.equals(vehicleId))).write(
      VehiclesTableCompanion(
        currentOdometerKm: Value(newOdometerKm),
        syncStatus: const Value('pending_update'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> saveQuickSpecs({
    required String vehicleId,
    String? oilViscosity,
    double? oilCapacityL,
    String? coolantSpec,
    double? coolantCapacityL,
    String? frontTireSize,
    String? rearTireSize,
    double? frontTirePressureBar,
    double? rearTirePressureBar,
    int? wiperDriverMm,
    int? wiperPassengerMm,
    int? wiperRearMm,
    String? batterySpec,
    double? sparkPlugGapMm,
    int? wheelLugTorqueNm,
    String? chainPitchMm,
  }) async {
    final now = DateTime.now().toUtc();
    await db.into(db.vehicleQuickSpecsTable).insertOnConflictUpdate(
      VehicleQuickSpecsTableCompanion(
        vehicleId: Value(vehicleId),
        oilViscosity: Value(oilViscosity),
        oilCapacityL: Value(oilCapacityL),
        coolantSpec: Value(coolantSpec),
        coolantCapacityL: Value(coolantCapacityL),
        frontTireSize: Value(frontTireSize),
        rearTireSize: Value(rearTireSize),
        frontTirePressureBar: Value(frontTirePressureBar),
        rearTirePressureBar: Value(rearTirePressureBar),
        wiperDriverMm: Value(wiperDriverMm),
        wiperPassengerMm: Value(wiperPassengerMm),
        wiperRearMm: Value(wiperRearMm),
        batterySpec: Value(batterySpec),
        sparkPlugGapMm: Value(sparkPlugGapMm),
        wheelLugTorqueNm: Value(wheelLugTorqueNm),
        chainPitchMm: Value(chainPitchMm),
        syncStatus: const Value('pending_update'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> softDeleteVehicle(String vehicleId) async {
    final now = DateTime.now().toUtc();
    await (db.update(db.vehiclesTable)..where((v) => v.id.equals(vehicleId))).write(
      VehiclesTableCompanion(
        isDeleted: const Value(true),
        syncStatus: const Value('pending_delete'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<int> countPendingSyncRows() async {
    final vCount = await (db.select(db.vehiclesTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
    final lCount = await (db.select(db.maintenanceLogsTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
    final fCount = await (db.select(db.fuelLogsTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
    final sCount = await (db.select(db.diagnosticSymptomsTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
    final iCount = await (db.select(db.garageInventoryTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();

    return vCount.length + lCount.length + fCount.length + sCount.length + iCount.length;
  }
}
