// =============================================================================
// CarLog Offline-First Background Sync Engine
// Orchestrates Bidirectional Delta Sync (Push Pending -> Pull Remote Delta)
// =============================================================================

import 'package:drift/drift.dart';
import '../../core/network/api_client.dart';
import '../../core/network/connectivity_guard.dart';
import '../local/database.dart';

class SyncResult {
  final bool success;
  final int pushedCount;
  final int pulledCount;
  final String? errorMessage;
  final DateTime syncTime;

  SyncResult({
    required this.success,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.errorMessage,
    required this.syncTime,
  });
}

class SyncEngine {
  final AppDatabase db;
  final ApiClient apiClient;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncEngine({required this.db, required this.apiClient});

  /// Perform full bidirectional delta synchronization
  Future<SyncResult> synchronize() async {
    if (_isSyncing) {
      return SyncResult(success: false, errorMessage: 'Sync already in progress', syncTime: DateTime.now());
    }

    final hasNet = await ConnectivityGuard.hasInternet();
    if (!hasNet) {
      return SyncResult(success: false, errorMessage: 'Offline: Internet connection required for sync', syncTime: DateTime.now());
    }

    final token = await apiClient.getAccessToken();
    if (token == null || token.isEmpty) {
      return SyncResult(success: false, errorMessage: 'Authentication required for sync', syncTime: DateTime.now());
    }

    _isSyncing = true;
    int pushedTotal = 0;
    int pulledTotal = 0;

    try {
      // -----------------------------------------------------------------------
      // 1. PUSH PHASE: Gather and push pending local records
      // -----------------------------------------------------------------------
      final pendingVehicles = await (db.select(db.vehiclesTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
      final pendingSpecs = await (db.select(db.vehicleQuickSpecsTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
      final pendingContacts = await (db.select(db.contactsDirectoryTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
      final pendingVisits = await (db.select(db.serviceVisitsTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
      final pendingLogs = await (db.select(db.maintenanceLogsTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
      final pendingSymptoms = await (db.select(db.diagnosticSymptomsTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
      final pendingFuel = await (db.select(db.fuelLogsTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();
      final pendingInventory = await (db.select(db.garageInventoryTable)..where((t) => t.syncStatus.isNotValue('synced'))).get();

      final pendingCount = pendingVehicles.length +
          pendingSpecs.length +
          pendingContacts.length +
          pendingVisits.length +
          pendingLogs.length +
          pendingSymptoms.length +
          pendingFuel.length +
          pendingInventory.length;

      if (pendingCount > 0) {
        final pushPayload = {
          'vehicles': pendingVehicles.map((v) => {
            'id': v.id,
            'vehicle_type': v.vehicleType,
            'vin': v.vin,
            'plate_number': v.plateNumber,
            'make': v.make,
            'model': v.model,
            'year': v.year,
            'engine_displacement_cc': v.engineDisplacementCc,
            'engine_code': v.engineCode,
            'power_kw': v.powerKw,
            'transmission_type': v.transmissionType,
            'fuel_type': v.fuelType,
            'acquisition_odometer_km': v.acquisitionOdometerKm,
            'current_odometer_km': v.currentOdometerKm,
            'photo_url': v.photoUrl,
            'public_share_token': v.publicShareToken,
            'hide_costs_on_share': v.hideCostsOnShare ? 1 : 0,
            'is_deleted': v.isDeleted ? 1 : 0,
            'sync_status': v.syncStatus,
          }).toList(),
          'vehicle_quick_specs': pendingSpecs.map((s) => {
            'vehicle_id': s.vehicleId,
            'oil_viscosity': s.oilViscosity,
            'oil_capacity_l': s.oilCapacityL,
            'coolant_spec': s.coolantSpec,
            'coolant_capacity_l': s.coolantCapacityL,
            'front_tire_size': s.frontTireSize,
            'rear_tire_size': s.rearTireSize,
            'front_tire_pressure_bar': s.frontTirePressureBar,
            'rear_tire_pressure_bar': s.rearTirePressureBar,
            'wiper_driver_mm': s.wiperDriverMm,
            'wiper_passenger_mm': s.wiperPassengerMm,
            'wiper_rear_mm': s.wiperRearMm,
            'battery_spec': s.batterySpec,
            'spark_plug_gap_mm': s.sparkPlugGapMm,
            'wheel_lug_torque_nm': s.wheelLugTorqueNm,
            'chain_pitch_mm': s.chainPitchMm,
          }).toList(),
          'contacts_directory': pendingContacts.map((c) => {
            'id': c.id,
            'shop_name': c.shopName,
            'specialty': c.specialty,
            'phone': c.phone,
            'location_notes': c.locationNotes,
            'is_deleted': c.isDeleted ? 1 : 0,
            'sync_status': c.syncStatus,
          }).toList(),
          'service_visits': pendingVisits.map((v) => {
            'id': v.id,
            'vehicle_id': v.vehicleId,
            'contact_id': v.contactId,
            'service_date': v.serviceDate.toIso8601String().substring(0, 10),
            'odometer_km': v.odometerKm,
            'visit_title': v.visitTitle,
            'receipt_photo_url': v.receiptPhotoUrl,
            'notes': v.notes,
            'is_deleted': v.isDeleted ? 1 : 0,
            'sync_status': v.syncStatus,
          }).toList(),
          'maintenance_logs': pendingLogs.map((l) => {
            'id': l.id,
            'visit_id': l.visitId,
            'vehicle_id': l.vehicleId,
            'task_id': l.taskId,
            'contact_id': l.contactId,
            'service_date': l.serviceDate.toIso8601String().substring(0, 10),
            'odometer_km': l.odometerKm,
            'cost_parts_usd': l.costPartsUsd,
            'cost_labor_usd': l.costLaborUsd,
            'part_brand': l.partBrand,
            'part_number': l.partNumber,
            'fluid_volume_l': l.fluidVolumeL,
            'wheel_positions': l.wheelPositions,
            'tire_dot_code': l.tireDotCode,
            'measurement_mm': l.measurementMm,
            'warranty_expires_date': l.warrantyExpiresDate?.toIso8601String().substring(0, 10),
            'notes': l.notes,
            'receipt_photo_url': l.receiptPhotoUrl,
            'next_due_km': l.nextDueKm,
            'next_due_date': l.nextDueDate?.toIso8601String().substring(0, 10),
            'is_deleted': l.isDeleted ? 1 : 0,
            'sync_status': l.syncStatus,
          }).toList(),
          'diagnostic_symptoms': pendingSymptoms.map((s) => {
            'id': s.id,
            'vehicle_id': s.vehicleId,
            'resolved_by_log_id': s.resolvedByLogId,
            'logged_date': s.loggedDate.toIso8601String(),
            'odometer_km': s.odometerKm,
            'obd_code': s.obdCode,
            'engine_state': s.engineState,
            'symptom_description': s.symptomDescription,
            'audio_clip_url': s.audioClipUrl,
            'is_resolved': s.isResolved ? 1 : 0,
            'is_deleted': s.isDeleted ? 1 : 0,
            'sync_status': s.syncStatus,
          }).toList(),
          'fuel_logs': pendingFuel.map((f) => {
            'id': f.id,
            'vehicle_id': f.vehicleId,
            'fill_date': f.fillDate.toIso8601String(),
            'odometer_km': f.odometerKm,
            'fuel_liters': f.fuelLiters,
            'price_per_liter_usd': f.pricePerLiterUsd,
            'total_cost_usd': f.totalCostUsd,
            'is_full_tank': f.isFullTank ? 1 : 0,
            'calculated_l_per_100km': f.calculatedLPer100km,
            'is_deleted': f.isDeleted ? 1 : 0,
            'sync_status': f.syncStatus,
          }).toList(),
          'garage_inventory': pendingInventory.map((i) => {
            'id': i.id,
            'vehicle_id': i.vehicleId,
            'task_id': i.taskId,
            'item_name': i.itemName,
            'part_brand': i.partBrand,
            'part_number': i.partNumber,
            'quantity': i.quantity,
            'unit_label': i.unitLabel,
            'purchase_price_usd': i.purchasePriceUsd,
            'is_deleted': i.isDeleted ? 1 : 0,
            'sync_status': i.syncStatus,
          }).toList(),
        };

        final pushResponse = await apiClient.dio.post('/sync/push', data: pushPayload);
        if (pushResponse.statusCode == 200) {
          // Mark all pushed records as synced locally
          await db.batch((b) {
            for (final v in pendingVehicles) {
              b.update(db.vehiclesTable, const VehiclesTableCompanion(syncStatus: Value('synced')), where: (tbl) => tbl.id.equals(v.id));
            }
            for (final s in pendingSpecs) {
              b.update(db.vehicleQuickSpecsTable, const VehicleQuickSpecsTableCompanion(syncStatus: Value('synced')), where: (tbl) => tbl.vehicleId.equals(s.vehicleId));
            }
            for (final c in pendingContacts) {
              b.update(db.contactsDirectoryTable, const ContactsDirectoryTableCompanion(syncStatus: Value('synced')), where: (tbl) => tbl.id.equals(c.id));
            }
            for (final v in pendingVisits) {
              b.update(db.serviceVisitsTable, const ServiceVisitsTableCompanion(syncStatus: Value('synced')), where: (tbl) => tbl.id.equals(v.id));
            }
            for (final l in pendingLogs) {
              b.update(db.maintenanceLogsTable, const MaintenanceLogsTableCompanion(syncStatus: Value('synced')), where: (tbl) => tbl.id.equals(l.id));
            }
            for (final s in pendingSymptoms) {
              b.update(db.diagnosticSymptomsTable, const DiagnosticSymptomsTableCompanion(syncStatus: Value('synced')), where: (tbl) => tbl.id.equals(s.id));
            }
            for (final f in pendingFuel) {
              b.update(db.fuelLogsTable, const FuelLogsTableCompanion(syncStatus: Value('synced')), where: (tbl) => tbl.id.equals(f.id));
            }
            for (final i in pendingInventory) {
              b.update(db.garageInventoryTable, const GarageInventoryTableCompanion(syncStatus: Value('synced')), where: (tbl) => tbl.id.equals(i.id));
            }
          });
          pushedTotal = pendingCount;
        }
      }

      // -----------------------------------------------------------------------
      // 2. PULL PHASE: Retrieve remote delta updates since last sync timestamp
      // -----------------------------------------------------------------------
      final lastSyncEntry = await (db.select(db.syncMetaTable)..where((m) => m.metaKey.equals('last_sync_timestamp'))).getSingleOrNull();
      final sinceParam = lastSyncEntry?.metaValue;

      final queryParams = sinceParam != null ? {'since': sinceParam} : <String, dynamic>{};
      final pullResponse = await apiClient.dio.get('/sync/pull', queryParameters: queryParams);

      if (pullResponse.statusCode == 200 && pullResponse.data?['data']?['delta'] != null) {
        final delta = pullResponse.data['data']['delta'] as Map<String, dynamic>;
        final serverTimestamp = pullResponse.data['data']['server_timestamp'] as String?;

        // Upsert pulled records into SQLite
        await db.transaction(() async {
          // Vehicles
          final remoteVehicles = delta['vehicles'] as List? ?? [];
          for (final rv in remoteVehicles) {
            await db.into(db.vehiclesTable).insertOnConflictUpdate(
              VehiclesTableCompanion(
                id: Value(rv['id']),
                userId: Value(rv['user_id']),
                vehicleType: Value(rv['vehicle_type'] ?? 'car'),
                vin: Value(rv['vin']),
                plateNumber: Value(rv['plate_number']),
                make: Value(rv['make']),
                model: Value(rv['model']),
                year: Value(int.parse(rv['year'].toString())),
                engineDisplacementCc: Value(rv['engine_displacement_cc'] != null ? int.parse(rv['engine_displacement_cc'].toString()) : null),
                engineCode: Value(rv['engine_code']),
                powerKw: Value(rv['power_kw'] != null ? int.parse(rv['power_kw'].toString()) : null),
                transmissionType: Value(rv['transmission_type'] ?? 'manual'),
                fuelType: Value(rv['fuel_type'] ?? 'gasoline'),
                acquisitionOdometerKm: Value(int.parse(rv['acquisition_odometer_km'].toString())),
                currentOdometerKm: Value(int.parse(rv['current_odometer_km'].toString())),
                photoUrl: Value(rv['photo_url']),
                publicShareToken: Value(rv['public_share_token']),
                hideCostsOnShare: Value(rv['hide_costs_on_share'] == 1 || rv['hide_costs_on_share'] == true),
                isDeleted: Value(rv['is_deleted'] == 1 || rv['is_deleted'] == true),
                syncStatus: const Value('synced'),
                updatedAt: Value(DateTime.tryParse(rv['updated_at']) ?? DateTime.now()),
              ),
            );
            pulledTotal++;
          }

          // Quick Specs
          final remoteSpecs = delta['vehicle_quick_specs'] as List? ?? [];
          for (final rs in remoteSpecs) {
            await db.into(db.vehicleQuickSpecsTable).insertOnConflictUpdate(
              VehicleQuickSpecsTableCompanion(
                vehicleId: Value(rs['vehicle_id']),
                oilViscosity: Value(rs['oil_viscosity']),
                oilCapacityL: Value(rs['oil_capacity_l'] != null ? double.parse(rs['oil_capacity_l'].toString()) : null),
                coolantSpec: Value(rs['coolant_spec']),
                coolantCapacityL: Value(rs['coolant_capacity_l'] != null ? double.parse(rs['coolant_capacity_l'].toString()) : null),
                frontTireSize: Value(rs['front_tire_size']),
                rearTireSize: Value(rs['rear_tire_size']),
                frontTirePressureBar: Value(rs['front_tire_pressure_bar'] != null ? double.parse(rs['front_tire_pressure_bar'].toString()) : null),
                rearTirePressureBar: Value(rs['rear_tire_pressure_bar'] != null ? double.parse(rs['rear_tire_pressure_bar'].toString()) : null),
                wiperDriverMm: Value(rs['wiper_driver_mm'] != null ? int.parse(rs['wiper_driver_mm'].toString()) : null),
                wiperPassengerMm: Value(rs['wiper_passenger_mm'] != null ? int.parse(rs['wiper_passenger_mm'].toString()) : null),
                wiperRearMm: Value(rs['wiper_rear_mm'] != null ? int.parse(rs['wiper_rear_mm'].toString()) : null),
                batterySpec: Value(rs['battery_spec']),
                sparkPlugGapMm: Value(rs['spark_plug_gap_mm'] != null ? double.parse(rs['spark_plug_gap_mm'].toString()) : null),
                wheelLugTorqueNm: Value(rs['wheel_lug_torque_nm'] != null ? int.parse(rs['wheel_lug_torque_nm'].toString()) : null),
                chainPitchMm: Value(rs['chain_pitch_mm']),
                syncStatus: const Value('synced'),
                updatedAt: Value(DateTime.tryParse(rs['updated_at']) ?? DateTime.now()),
              ),
            );
            pulledTotal++;
          }

          // Maintenance Logs
          final remoteLogs = delta['maintenance_logs'] as List? ?? [];
          for (final rl in remoteLogs) {
            await db.into(db.maintenanceLogsTable).insertOnConflictUpdate(
              MaintenanceLogsTableCompanion(
                id: Value(rl['id']),
                visitId: Value(rl['visit_id']),
                vehicleId: Value(rl['vehicle_id']),
                taskId: Value(rl['task_id']),
                contactId: Value(rl['contact_id']),
                serviceDate: Value(DateTime.parse(rl['service_date'])),
                odometerKm: Value(int.parse(rl['odometer_km'].toString())),
                costPartsUsd: Value(double.parse((rl['cost_parts_usd'] ?? 0).toString())),
                costLaborUsd: Value(double.parse((rl['cost_labor_usd'] ?? 0).toString())),
                partBrand: Value(rl['part_brand']),
                partNumber: Value(rl['part_number']),
                fluidVolumeL: Value(rl['fluid_volume_l'] != null ? double.parse(rl['fluid_volume_l'].toString()) : null),
                wheelPositions: Value(rl['wheel_positions']),
                tireDotCode: Value(rl['tire_dot_code']),
                measurementMm: Value(rl['measurement_mm'] != null ? double.parse(rl['measurement_mm'].toString()) : null),
                warrantyExpiresDate: Value(rl['warranty_expires_date'] != null ? DateTime.tryParse(rl['warranty_expires_date']) : null),
                notes: Value(rl['notes']),
                receiptPhotoUrl: Value(rl['receipt_photo_url']),
                nextDueKm: Value(rl['next_due_km'] != null ? int.parse(rl['next_due_km'].toString()) : null),
                nextDueDate: Value(rl['next_due_date'] != null ? DateTime.tryParse(rl['next_due_date']) : null),
                isDeleted: Value(rl['is_deleted'] == 1 || rl['is_deleted'] == true),
                syncStatus: const Value('synced'),
                updatedAt: Value(DateTime.tryParse(rl['updated_at']) ?? DateTime.now()),
              ),
            );
            pulledTotal++;
          }

          // Fuel Logs
          final remoteFuel = delta['fuel_logs'] as List? ?? [];
          for (final rf in remoteFuel) {
            await db.into(db.fuelLogsTable).insertOnConflictUpdate(
              FuelLogsTableCompanion(
                id: Value(rf['id']),
                vehicleId: Value(rf['vehicle_id']),
                fillDate: Value(DateTime.parse(rf['fill_date'])),
                odometerKm: Value(int.parse(rf['odometer_km'].toString())),
                fuelLiters: Value(double.parse(rf['fuel_liters'].toString())),
                pricePerLiterUsd: Value(double.parse(rf['price_per_liter_usd'].toString())),
                totalCostUsd: Value(double.parse(rf['total_cost_usd'].toString())),
                isFullTank: Value(rf['is_full_tank'] == 1 || rf['is_full_tank'] == true),
                calculatedLPer100km: Value(rf['calculated_l_per_100km'] != null ? double.parse(rf['calculated_l_per_100km'].toString()) : null),
                isDeleted: Value(rf['is_deleted'] == 1 || rf['is_deleted'] == true),
                syncStatus: const Value('synced'),
                updatedAt: Value(DateTime.tryParse(rf['updated_at']) ?? DateTime.now()),
              ),
            );
            pulledTotal++;
          }

          // Save server timestamp
          if (serverTimestamp != null) {
            await db.into(db.syncMetaTable).insertOnConflictUpdate(
              SyncMetaTableCompanion(
                metaKey: const Value('last_sync_timestamp'),
                metaValue: Value(serverTimestamp),
              ),
            );
          }
        });
      }

      return SyncResult(
        success: true,
        pushedCount: pushedTotal,
        pulledCount: pulledTotal,
        syncTime: DateTime.now(),
      );

    } catch (e) {
      return SyncResult(
        success: false,
        pushedCount: pushedTotal,
        pulledCount: pulledTotal,
        errorMessage: e.toString(),
        syncTime: DateTime.now(),
      );
    } finally {
      _isSyncing = false;
    }
  }
}
