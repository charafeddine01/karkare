// =============================================================================
// CarLog Digital Service Book, PDF Export & QR Code Share Screen
// PDF Resale Report, Public QR Web View & Ownership Transfer Archive
// =============================================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../data/local/database.dart';
import '../../core/network/toast_service.dart';

class ServiceReportExportScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const ServiceReportExportScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<ServiceReportExportScreen> createState() => _ServiceReportExportScreenState();
}

class _ServiceReportExportScreenState extends ConsumerState<ServiceReportExportScreen> {
  bool _hideCostsOnExport = true;
  bool _isGeneratingShare = false;

  Future<void> _generatePdfReport(VehiclesTableData vehicle, List<MaintenanceLogsTableData> logs, VehicleQuickSpecsTableData? specs) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CARLOG VERIFIED SERVICE BOOK', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Official Maintenance History & Specification Record', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text('100% METRIC', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            // Vehicle Specs
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('${vehicle.year} ${vehicle.make} ${vehicle.model}', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('VIN: ${vehicle.vin ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Plate: ${vehicle.plateNumber ?? 'N/A'}', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text('Type: ${vehicle.vehicleType.toUpperCase()} | Fuel: ${vehicle.fuelType.toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Current Odometer: ${vehicle.currentOdometerKm} km', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Engine: ${vehicle.engineDisplacementCc ?? '-'} cc (${vehicle.powerKw ?? '-'} kW)', style: const pw.TextStyle(fontSize: 10)),
                        if (specs != null) ...[
                          pw.Text('Engine Oil: ${specs.oilViscosity ?? '-'} (${specs.oilCapacityL ?? '-'} L)', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Tire Pressure: F ${specs.frontTirePressureBar ?? '-'} Bar | R ${specs.rearTirePressureBar ?? '-'} Bar', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Text('CHRONOLOGICAL SERVICE RECORDS (${logs.length})', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),

            // Table of Logs
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Odometer',
                'Task / Component',
                'Part Brand & Number',
                'Fluid / Position',
                if (!_hideCostsOnExport) 'Cost (\$ USD)',
              ],
              data: logs.map((l) {
                return [
                  DateFormat('yyyy-MM-dd').format(l.serviceDate),
                  '${l.odometerKm} km',
                  'Task #${l.taskId.substring(0, 8)}',
                  '${l.partBrand ?? ''} ${l.partNumber ?? ''}',
                  l.fluidVolumeL != null ? '${l.fluidVolumeL} L' : (l.wheelPositions ?? '-'),
                  if (!_hideCostsOnExport) '\$${(l.costPartsUsd + l.costLaborUsd).toStringAsFixed(2)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            ),

            pw.SizedBox(height: 30),
            pw.Text('Generated by CarLog Garage Platform. All units Metric (km, L, Bar).', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'CarLog_${vehicle.make}_${vehicle.model}_Service_History.pdf',
    );
  }

  Future<void> _generateOrToggleShareToken(VehiclesTableData vehicle) async {
    setState(() => _isGeneratingShare = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.post(
        '/vehicles/${vehicle.id}/share-token',
        data: {'hide_costs': _hideCostsOnExport ? 1 : 0},
      );

      if (res.statusCode == 200 && res.data?['data'] != null) {
        final token = res.data['data']['public_share_token'];
        // Update local Drift record
        await ref.read(vehicleDaoProvider).upsertVehicle(
          id: vehicle.id,
          userId: vehicle.userId,
          vehicleType: vehicle.vehicleType,
          vin: vehicle.vin,
          plateNumber: vehicle.plateNumber,
          make: vehicle.make,
          model: vehicle.model,
          year: vehicle.year,
          displacementCc: vehicle.engineDisplacementCc,
          engineCode: vehicle.engineCode,
          powerKw: vehicle.powerKw,
          transmissionType: vehicle.transmissionType,
          fuelType: vehicle.fuelType,
          acquisitionOdometerKm: vehicle.acquisitionOdometerKm,
          currentOdometerKm: vehicle.currentOdometerKm,
          publicShareToken: token,
          hideCostsOnShare: _hideCostsOnExport,
        );

        ref.invalidate(vehiclesStreamProvider);
        ToastService.show('Public QR share link updated!', type: ToastType.success);
      }
    } catch (e) {
      ToastService.show('Failed to generate share link: $e', type: ToastType.error);
    } finally {
      setState(() => _isGeneratingShare = false);
    }
  }

  void _exportOwnershipTransferArchive(VehiclesTableData vehicle, List<MaintenanceLogsTableData> logs) {
    final archive = {
      'carlog_version': '1.0',
      'exported_at': DateTime.now().toIso8601String(),
      'vehicle': {
        'make': vehicle.make,
        'model': vehicle.model,
        'year': vehicle.year,
        'vin': vehicle.vin,
        'displacement_cc': vehicle.engineDisplacementCc,
        'power_kw': vehicle.powerKw,
        'current_odometer_km': vehicle.currentOdometerKm,
      },
      'service_history': logs.map((l) => {
        'service_date': l.serviceDate.toIso8601String(),
        'odometer_km': l.odometerKm,
        'part_brand': l.partBrand,
        'part_number': l.partNumber,
        'fluid_volume_l': l.fluidVolumeL,
        'wheel_positions': l.wheelPositions,
        'notes': l.notes,
        if (!_hideCostsOnExport) 'cost_total_usd': l.costPartsUsd + l.costLaborUsd,
      }).toList(),
    };

    final jsonStr = jsonEncode(archive);
    Clipboard.setData(ClipboardData(text: jsonStr));
    ToastService.show(
      'Encrypted .carlog archive JSON copied to clipboard! Ready to transfer.',
      type: ToastType.success,
      duration: const Duration(seconds: 5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesStreamProvider).value ?? [];
    if (vehicles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service Book & QR')),
        body: const Center(child: Text('Add a vehicle first.')),
      );
    }

    final vehicle = vehicles.firstWhere(
      (v) => v.id == widget.vehicleId,
      orElse: () => vehicles.first,
    );

    final shareUrl = vehicle.publicShareToken != null
        ? 'https://carlog.charafeddine.xyz/v/${vehicle.publicShareToken}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Export & QR: ${vehicle.make} ${vehicle.model}'),
      ),
      body: StreamBuilder<List<MaintenanceLogsTableData>>(
        stream: ref.watch(maintenanceDaoProvider).watchVehicleLogs(vehicle.id),
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Privacy / Cost Hiding Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: CarLogTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CarLogTheme.borderDark),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hide Financial Costs on Share/Export', style: TextStyle(fontWeight: FontWeight.bold, color: CarLogTheme.textMain)),
                    subtitle: const Text('Protects your private pricing while proving verified service history', style: TextStyle(fontSize: 12, color: CarLogTheme.textMuted)),
                    value: _hideCostsOnExport,
                    activeColor: CarLogTheme.primaryCyan,
                    onChanged: (val) => setState(() => _hideCostsOnExport = val),
                  ),
                ),
                const SizedBox(height: 20),

                // Card 1: Public QR Share Code
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'Public QR Digital Service Book',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CarLogTheme.textMain),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Allow prospective vehicle buyers or workshops to scan and review verified service history online.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: CarLogTheme.textMuted),
                        ),
                        const SizedBox(height: 20),

                        if (shareUrl != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: shareUrl,
                              version: QrVersions.auto,
                              size: 180.0,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SelectableText(
                            shareUrl,
                            style: const TextStyle(fontSize: 12, color: CarLogTheme.primaryCyan, fontFamily: 'monospace'),
                          ),
                        ] else ...[
                          Icon(Icons.qr_code_2_rounded, size: 80, color: CarLogTheme.textMuted.withOpacity(0.4)),
                          const SizedBox(height: 8),
                          const Text('No public share token generated yet.', style: TextStyle(fontSize: 12, color: CarLogTheme.textMuted)),
                        ],

                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          icon: _isGeneratingShare
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.share_rounded),
                          label: Text(shareUrl != null ? 'UPDATE SHARING PREFERENCES' : 'GENERATE PUBLIC QR SHARE LINK'),
                          onPressed: _isGeneratingShare ? null : () => _generateOrToggleShareToken(vehicle),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Card 2: PDF Resale Report
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CarLogTheme.accentRed.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.picture_as_pdf_rounded, color: CarLogTheme.accentRed, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PDF Resale Service Report',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CarLogTheme.textMain),
                                  ),
                                  Text(
                                    'Standardized printable document with vehicle specs & logs',
                                    style: TextStyle(fontSize: 11.5, color: CarLogTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            side: const BorderSide(color: CarLogTheme.primaryCyan),
                          ),
                          icon: const Icon(Icons.print_rounded, color: CarLogTheme.primaryCyan),
                          label: const Text('GENERATE & PRINT PDF REPORT', style: TextStyle(color: CarLogTheme.primaryCyan, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final specs = await ref.read(vehicleDaoProvider).getQuickSpecs(vehicle.id);
                            await _generatePdfReport(vehicle, logs, specs);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Card 3: Ownership Transfer Archive
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CarLogTheme.accentGreen.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.drive_file_move_rounded, color: CarLogTheme.accentGreen, size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ownership Transfer Package',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CarLogTheme.textMain),
                                  ),
                                  Text(
                                    'Export .carlog encrypted archive for transferring to another user',
                                    style: TextStyle(fontSize: 11.5, color: CarLogTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            side: const BorderSide(color: CarLogTheme.accentGreen),
                          ),
                          icon: const Icon(Icons.copy_rounded, color: CarLogTheme.accentGreen),
                          label: const Text('COPY .CARLOG TRANSFER ARCHIVE', style: TextStyle(color: CarLogTheme.accentGreen, fontWeight: FontWeight.bold)),
                          onPressed: () => _exportOwnershipTransferArchive(vehicle, logs),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
