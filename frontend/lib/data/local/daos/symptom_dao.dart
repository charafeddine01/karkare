// =============================================================================
// CarLog Diagnostic Symptom Journal & OBD-II DAO
// Pre-repair symptoms, OBD-II offline search & 10s audio clip logging
// =============================================================================

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';

class ObdCodeEntry {
  final String code;
  final String category;
  final String description;
  final String severity;

  ObdCodeEntry({
    required this.code,
    required this.category,
    required this.description,
    required this.severity,
  });

  factory ObdCodeEntry.fromJson(Map<String, dynamic> json) {
    return ObdCodeEntry(
      code: json['code'] ?? '',
      category: json['category'] ?? 'powertrain',
      description: json['description'] ?? '',
      severity: json['severity'] ?? 'medium',
    );
  }
}

class SymptomDao {
  final AppDatabase db;
  static const _uuid = Uuid();
  static List<ObdCodeEntry>? _cachedObdCodes;

  SymptomDao(this.db);

  Stream<List<DiagnosticSymptomsTableData>> watchVehicleSymptoms(String vehicleId) {
    return (db.select(db.diagnosticSymptomsTable)
          ..where((s) => s.vehicleId.equals(vehicleId) & s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm(expression: s.loggedDate, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<String> addSymptom({
    required String vehicleId,
    required DateTime loggedDate,
    required int odometerKm,
    String? obdCode,
    String engineState = 'other',
    required String symptomDescription,
    String? audioClipUrl,
  }) async {
    final symptomId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await db.into(db.diagnosticSymptomsTable).insert(
      DiagnosticSymptomsTableCompanion(
        id: Value(symptomId),
        vehicleId: Value(vehicleId),
        loggedDate: Value(loggedDate),
        odometerKm: Value(odometerKm),
        obdCode: Value(obdCode?.toUpperCase()),
        engineState: Value(engineState),
        symptomDescription: Value(symptomDescription),
        audioClipUrl: Value(audioClipUrl),
        isResolved: const Value(false),
        isDeleted: const Value(false),
        syncStatus: const Value('pending_insert'),
        updatedAt: Value(now),
      ),
    );

    return symptomId;
  }

  Future<void> resolveSymptom({
    required String symptomId,
    required String maintenanceLogId,
  }) async {
    final now = DateTime.now().toUtc();
    await (db.update(db.diagnosticSymptomsTable)..where((s) => s.id.equals(symptomId))).write(
      DiagnosticSymptomsTableCompanion(
        isResolved: const Value(true),
        resolvedByLogId: Value(maintenanceLogId),
        syncStatus: const Value('pending_update'),
        updatedAt: Value(now),
      ),
    );
  }

  /// Offline OBD-II Code Lookup from bundled assets/obd_codes.json
  static Future<List<ObdCodeEntry>> searchOfflineObd(String query) async {
    final cleanQuery = query.trim().toUpperCase();
    if (_cachedObdCodes == null) {
      try {
        final jsonStr = await rootBundle.loadString('assets/obd_codes.json');
        final list = jsonDecode(jsonStr) as List;
        _cachedObdCodes = list.map((e) => ObdCodeEntry.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        _cachedObdCodes = [];
      }
    }

    if (cleanQuery.isEmpty) {
      return _cachedObdCodes!.take(10).toList();
    }

    return _cachedObdCodes!.where((c) =>
        c.code.contains(cleanQuery) || c.description.toUpperCase().contains(cleanQuery)).toList();
  }
}
