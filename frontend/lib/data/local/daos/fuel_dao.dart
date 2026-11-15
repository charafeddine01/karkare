// =============================================================================
// CarLog Fuel & Cost-Per-Kilometer ($/km) TCO Analytics DAO
// Strictly USD ($) & Metric (Liters, Kilometers, L/100km, km/L)
// =============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';

class VehicleTcoAnalytics {
  final double totalMaintenanceUsd;
  final double totalFuelUsd;
  final double overallTotalUsd;
  final int totalDistanceKm;
  final double costPerKmUsd;
  final double? averageLPer100km;
  final double? averageKmPerL;
  final int totalFuelLogs;
  final int totalServiceLogs;

  VehicleTcoAnalytics({
    required this.totalMaintenanceUsd,
    required this.totalFuelUsd,
    required this.overallTotalUsd,
    required this.totalDistanceKm,
    required this.costPerKmUsd,
    this.averageLPer100km,
    this.averageKmPerL,
    required this.totalFuelLogs,
    required this.totalServiceLogs,
  });
}

class FuelDao {
  final AppDatabase db;
  static const _uuid = Uuid();

  FuelDao(this.db);

  Stream<List<FuelLogsTableData>> watchVehicleFuelLogs(String vehicleId) {
    return (db.select(db.fuelLogsTable)
          ..where((f) => f.vehicleId.equals(vehicleId) & f.isDeleted.equals(false))
          ..orderBy([(f) => OrderingTerm(expression: f.fillDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<String> addFuelLog({
    required String vehicleId,
    required DateTime fillDate,
    required int odometerKm,
    required double fuelLiters,
    required double pricePerLiterUsd,
    required double totalCostUsd,
    bool isFullTank = true,
  }) async {
    final logId = _uuid.v4();
    final now = DateTime.now().toUtc();

    // Calculate consumption against last fill-up
    double? calculatedLPer100km;
    final lastLog = await (db.select(db.fuelLogsTable)
          ..where((f) => f.vehicleId.equals(vehicleId) & f.isDeleted.equals(false))
          ..orderBy([(f) => OrderingTerm(expression: f.fillDate, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();

    if (lastLog != null && odometerKm > lastLog.odometerKm && isFullTank && lastLog.isFullTank) {
      final distanceKm = odometerKm - lastLog.odometerKm;
      if (distanceKm > 0) {
        calculatedLPer100km = double.parse(((fuelLiters / distanceKm) * 100).toStringAsFixed(2));
      }
    }

    await db.into(db.fuelLogsTable).insert(
      FuelLogsTableCompanion(
        id: Value(logId),
        vehicleId: Value(vehicleId),
        fillDate: Value(fillDate),
        odometerKm: Value(odometerKm),
        fuelLiters: Value(fuelLiters),
        pricePerLiterUsd: Value(pricePerLiterUsd),
        totalCostUsd: Value(totalCostUsd),
        isFullTank: Value(isFullTank),
        calculatedLPer100km: Value(calculatedLPer100km),
        isDeleted: const Value(false),
        syncStatus: const Value('pending_insert'),
        updatedAt: Value(now),
      ),
    );

    // Update vehicle current odometer if higher
    final vehicle = await (db.select(db.vehiclesTable)..where((v) => v.id.equals(vehicleId))).getSingleOrNull();
    if (vehicle != null && odometerKm > vehicle.currentOdometerKm) {
      await (db.update(db.vehiclesTable)..where((v) => v.id.equals(vehicleId))).write(
        VehiclesTableCompanion(
          currentOdometerKm: Value(odometerKm),
          syncStatus: const Value('pending_update'),
          updatedAt: Value(now),
        ),
      );
    }

    return logId;
  }

  /// Compute Real Cost-Per-Kilometer ($/km) & TCO Analytics
  Future<VehicleTcoAnalytics> getVehicleAnalytics(String vehicleId) async {
    final vehicle = await (db.select(db.vehiclesTable)..where((v) => v.id.equals(vehicleId))).getSingleOrNull();
    final acquisitionKm = vehicle?.acquisitionOdometerKm ?? 0;
    final currentKm = vehicle?.currentOdometerKm ?? 0;
    final totalDistanceKm = currentKm > acquisitionKm ? currentKm - acquisitionKm : 0;

    // Maintenance spend
    final maintenanceLogs = await (db.select(db.maintenanceLogsTable)
          ..where((l) => l.vehicleId.equals(vehicleId) & l.isDeleted.equals(false)))
        .get();

    double totalMaintUsd = 0.0;
    for (final l in maintenanceLogs) {
      totalMaintUsd += (l.costPartsUsd + l.costLaborUsd);
    }

    // Fuel spend
    final fuelLogs = await (db.select(db.fuelLogsTable)
          ..where((f) => f.vehicleId.equals(vehicleId) & f.isDeleted.equals(false)))
        .get();

    double totalFuelUsd = 0.0;
    double totalConsumptionSum = 0.0;
    int consumptionCount = 0;

    for (final f in fuelLogs) {
      totalFuelUsd += f.totalCostUsd;
      if (f.calculatedLPer100km != null && f.calculatedLPer100km! > 0) {
        totalConsumptionSum += f.calculatedLPer100km!;
        consumptionCount++;
      }
    }

    final overallTotalUsd = totalMaintUsd + totalFuelUsd;
    final costPerKm = totalDistanceKm > 0 ? (overallTotalUsd / totalDistanceKm) : 0.0;

    double? avgL100km;
    double? avgKmL;
    if (consumptionCount > 0) {
      avgL100km = double.parse((totalConsumptionSum / consumptionCount).toStringAsFixed(2));
      if (avgL100km > 0) {
        avgKmL = double.parse((100 / avgL100km).toStringAsFixed(2));
      }
    }

    return VehicleTcoAnalytics(
      totalMaintenanceUsd: double.parse(totalMaintUsd.toStringAsFixed(2)),
      totalFuelUsd: double.parse(totalFuelUsd.toStringAsFixed(2)),
      overallTotalUsd: double.parse(overallTotalUsd.toStringAsFixed(2)),
      totalDistanceKm: totalDistanceKm,
      costPerKmUsd: double.parse(costPerKm.toStringAsFixed(3)),
      averageLPer100km: avgL100km,
      averageKmPerL: avgKmL,
      totalFuelLogs: fuelLogs.length,
      totalServiceLogs: maintenanceLogs.length,
    );
  }
}
