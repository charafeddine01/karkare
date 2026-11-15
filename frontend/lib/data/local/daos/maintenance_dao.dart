// =============================================================================
// CarLog Maintenance DAO
// Smart Service Bundles, Multi-Task Visits, Dual-Trigger Reminders & Tier 1 Parts
// =============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';

class ServiceBundleItemInput {
  final String taskId;
  final double costPartsUsd;
  final double costLaborUsd;
  final String? partBrand;
  final String? partNumber;
  final double? fluidVolumeL;
  final String? wheelPositions; // e.g. 'FL,FR', 'RL,RR', 'Spare', 'Front', 'Rear'
  final String? tireDotCode;
  final double? measurementMm; // tread depth or pad thickness
  final DateTime? warrantyExpiresDate;
  final String? notes;
  final int? nextDueKm;
  final DateTime? nextDueDate;

  ServiceBundleItemInput({
    required this.taskId,
    this.costPartsUsd = 0.0,
    this.costLaborUsd = 0.0,
    this.partBrand,
    this.partNumber,
    this.fluidVolumeL,
    this.wheelPositions,
    this.tireDotCode,
    this.measurementMm,
    this.warrantyExpiresDate,
    this.notes,
    this.nextDueKm,
    this.nextDueDate,
  });
}

enum ReminderUrgency { overdue, dueSoon, upcoming }

class TaskReminderStatus {
  final MaintenanceLogsTableData log;
  final MaintenanceTasksTemplateTableData task;
  final ReminderUrgency urgency;
  final int? remainingKm;
  final int? remainingDays;

  TaskReminderStatus({
    required this.log,
    required this.task,
    required this.urgency,
    this.remainingKm,
    this.remainingDays,
  });
}

class MaintenanceDao {
  final AppDatabase db;
  static const _uuid = Uuid();

  MaintenanceDao(this.db);

  /// Fetch all system and user maintenance task templates filtered by vehicle type
  Stream<List<MaintenanceTasksTemplateTableData>> watchTasks(String vehicleType) {
    return (db.select(db.maintenanceTasksTemplateTable)
          ..where((t) =>
              t.isDeleted.equals(false) &
              (t.applicableTo.equals('all') | t.applicableTo.equals(vehicleType)))
          ..orderBy([(t) => OrderingTerm(expression: t.category), (t) => OrderingTerm(expression: t.taskName)]))
        .watch();
  }

  /// Watch service history for a vehicle
  Stream<List<MaintenanceLogsTableData>> watchVehicleLogs(String vehicleId) {
    return (db.select(db.maintenanceLogsTable)
          ..where((l) => l.vehicleId.equals(vehicleId) & l.isDeleted.equals(false))
          ..orderBy([(l) => OrderingTerm(expression: l.serviceDate, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Log a Smart Service Bundle (1 Visit + Multiple Maintenance Tasks)
  Future<String> logServiceBundle({
    required String vehicleId,
    String? contactId,
    required DateTime serviceDate,
    required int odometerKm,
    String? visitTitle,
    String? receiptPhotoUrl,
    String? generalNotes,
    required List<ServiceBundleItemInput> items,
  }) async {
    final visitId = _uuid.v4();
    final now = DateTime.now().toUtc();

    return await db.transaction(() async {
      // 1. Insert Service Visit
      await db.into(db.serviceVisitsTable).insert(
        ServiceVisitsTableCompanion(
          id: Value(visitId),
          vehicleId: Value(vehicleId),
          contactId: Value(contactId),
          serviceDate: Value(serviceDate),
          odometerKm: Value(odometerKm),
          visitTitle: Value(visitTitle),
          receiptPhotoUrl: Value(receiptPhotoUrl),
          notes: Value(generalNotes),
          isDeleted: const Value(false),
          syncStatus: const Value('pending_insert'),
          updatedAt: Value(now),
        ),
      );

      // 2. Insert each Maintenance Task Log
      for (final item in items) {
        final logId = _uuid.v4();
        await db.into(db.maintenanceLogsTable).insert(
          MaintenanceLogsTableCompanion(
            id: Value(logId),
            visitId: Value(visitId),
            vehicleId: Value(vehicleId),
            taskId: Value(item.taskId),
            contactId: Value(contactId),
            serviceDate: Value(serviceDate),
            odometerKm: Value(odometerKm),
            costPartsUsd: Value(item.costPartsUsd),
            costLaborUsd: Value(item.costLaborUsd),
            partBrand: Value(item.partBrand),
            partNumber: Value(item.partNumber?.toUpperCase()),
            fluidVolumeL: Value(item.fluidVolumeL),
            wheelPositions: Value(item.wheelPositions),
            tireDotCode: Value(item.tireDotCode),
            measurementMm: Value(item.measurementMm),
            warrantyExpiresDate: Value(item.warrantyExpiresDate),
            notes: Value(item.notes),
            receiptPhotoUrl: Value(receiptPhotoUrl),
            nextDueKm: Value(item.nextDueKm),
            nextDueDate: Value(item.nextDueDate),
            isDeleted: const Value(false),
            syncStatus: const Value('pending_insert'),
            updatedAt: Value(now),
          ),
        );
      }

      // 3. Update vehicle current odometer if higher
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

      return visitId;
    });
  }

  /// Tier 1 Part Suggestion: Query vehicle local history for previously used part number
  Future<Map<String, String>?> getTier1PartSuggestion({
    required String vehicleId,
    required String taskId,
  }) async {
    final query = (db.select(db.maintenanceLogsTable)
          ..where((l) =>
              l.vehicleId.equals(vehicleId) &
              l.taskId.equals(taskId) &
              l.partNumber.isNotNull() &
              l.isDeleted.equals(false))
          ..orderBy([(l) => OrderingTerm(expression: l.serviceDate, mode: OrderingMode.desc)])
          ..limit(1));

    final record = await query.getSingleOrNull();
    if (record != null && record.partNumber != null && record.partNumber!.trim().isNotEmpty) {
      return {
        'part_brand': record.partBrand ?? 'OEM / Genuine',
        'part_number': record.partNumber!,
        'badge': 'Previously used on this vehicle',
        'tier': '1',
      };
    }

    return null;
  }

  /// Calculate Dual-Trigger Maintenance Reminders (km + time) for a vehicle
  Future<List<TaskReminderStatus>> getVehicleReminders(String vehicleId, int currentOdometerKm) async {
    final logs = await (db.select(db.maintenanceLogsTable)
          ..where((l) =>
              l.vehicleId.equals(vehicleId) &
              l.isDeleted.equals(false) &
              (l.nextDueKm.isNotNull() | l.nextDueDate.isNotNull()))
          ..orderBy([(l) => OrderingTerm(expression: l.serviceDate, mode: OrderingMode.desc)]))
        .get();

    final now = DateTime.now();
    final List<TaskReminderStatus> reminders = [];

    // Group by task to only evaluate the most recent log per task
    final Map<String, MaintenanceLogsTableData> latestPerTask = {};
    for (final l in logs) {
      if (!latestPerTask.containsKey(l.taskId)) {
        latestPerTask[l.taskId] = l;
      }
    }

    for (final entry in latestPerTask.entries) {
      final log = entry.value;
      final task = await (db.select(db.maintenanceTasksTemplateTable)..where((t) => t.id.equals(log.taskId))).getSingleOrNull();
      if (task == null) continue;

      int? remainingKm;
      int? remainingDays;
      bool isOverdue = false;
      bool isDueSoon = false;

      if (log.nextDueKm != null) {
        remainingKm = log.nextDueKm! - currentOdometerKm;
        if (remainingKm <= 0) {
          isOverdue = true;
        } else if (remainingKm <= 500) {
          isDueSoon = true;
        }
      }

      if (log.nextDueDate != null) {
        remainingDays = log.nextDueDate!.difference(now).inDays;
        if (remainingDays <= 0) {
          isOverdue = true;
        } else if (remainingDays <= 14) {
          isDueSoon = true;
        }
      }

      ReminderUrgency urgency;
      if (isOverdue) {
        urgency = ReminderUrgency.overdue;
      } else if (isDueSoon) {
        urgency = ReminderUrgency.dueSoon;
      } else {
        urgency = ReminderUrgency.upcoming;
      }

      reminders.add(
        TaskReminderStatus(
          log: log,
          task: task,
          urgency: urgency,
          remainingKm: remainingKm,
          remainingDays: remainingDays,
        ),
      );
    }

    // Sort by urgency: overdue first, then dueSoon, then upcoming
    reminders.sort((a, b) => a.urgency.index.compareTo(b.urgency.index));
    return reminders;
  }
}
