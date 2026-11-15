// =============================================================================
// CarLog Fuel Tracker Screen
// Fuel Fill-Up Logging, Consumption (L/100km & km/L) & Fuel Cost History
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../data/local/database.dart';
import '../../widgets/metric_helper_chip.dart';
import '../../widgets/ocr_scan_button.dart';
import '../../core/network/toast_service.dart';

class FuelTrackerScreen extends ConsumerStatefulWidget {
  final String? vehicleId;

  const FuelTrackerScreen({super.key, this.vehicleId});

  @override
  ConsumerState<FuelTrackerScreen> createState() => _FuelTrackerScreenState();
}

class _FuelTrackerScreenState extends ConsumerState<FuelTrackerScreen> {
  void _showAddFuelModal(VehiclesTableData vehicle) {
    final odoController = TextEditingController(text: vehicle.currentOdometerKm.toString());
    final litersController = TextEditingController();
    final pricePerLController = TextEditingController();
    final totalCostController = TextEditingController();
    bool isFullTank = true;

    void calculateTotal() {
      final liters = double.tryParse(litersController.text.trim()) ?? 0.0;
      final price = double.tryParse(pricePerLController.text.trim()) ?? 0.0;
      if (liters > 0 && price > 0) {
        totalCostController.text = (liters * price).toStringAsFixed(2);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CarLogTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Log Fuel Fill-Up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CarLogTheme.textMain)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Odometer with OCR
                    TextFormField(
                      controller: odoController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Current Odometer (km) *',
                        suffixText: 'km',
                        suffixIcon: OcrScanButton(
                          scanType: OcrScanType.odometer,
                          onTextRecognized: (txt) {
                            final n = txt.replaceAll(RegExp(r'[^0-9]'), '');
                            if (n.isNotEmpty) odoController.text = n;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Fuel Liters + US Gallons helper chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: litersController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Fuel Volume (L) *', suffixText: 'L'),
                                onChanged: (_) => calculateTotal(),
                              ),
                              const SizedBox(height: 4),
                              MetricHelperChip(
                                controller: litersController,
                                type: MetricConversionType.gallonsToLiters,
                                label: 'US Gal -> L',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: pricePerLController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Price per Liter (\$ USD)', prefixText: '\$ '),
                            onChanged: (_) => calculateTotal(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Total Cost USD
                    TextFormField(
                      controller: totalCostController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Total Cost (\$ USD) *', prefixText: '\$ '),
                    ),
                    const SizedBox(height: 14),

                    // Full Tank Toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Full Tank Fill-Up', style: TextStyle(fontWeight: FontWeight.w600, color: CarLogTheme.textMain)),
                      subtitle: const Text('Enables accurate L/100km & km/L calculation', style: TextStyle(fontSize: 12, color: CarLogTheme.textMuted)),
                      value: isFullTank,
                      activeColor: CarLogTheme.primaryCyan,
                      onChanged: (val) => setModalState(() => isFullTank = val),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () async {
                        final odo = int.tryParse(odoController.text.trim());
                        final liters = double.tryParse(litersController.text.trim());
                        final price = double.tryParse(pricePerLController.text.trim()) ?? 0.0;
                        final total = double.tryParse(totalCostController.text.trim());

                        if (odo == null || liters == null || total == null) {
                          ToastService.show('Please fill required fuel fields', type: ToastType.warning);
                          return;
                        }

                        await ref.read(fuelDaoProvider).addFuelLog(
                          vehicleId: vehicle.id,
                          fillDate: DateTime.now(),
                          odometerKm: odo,
                          fuelLiters: liters,
                          pricePerLiterUsd: price,
                          totalCostUsd: total,
                          isFullTank: isFullTank,
                        );

                        ref.invalidate(vehiclesStreamProvider);

                        if (mounted) {
                          Navigator.pop(ctx);
                          ToastService.show('Fuel fill-up logged successfully!', type: ToastType.success);
                        }
                      },
                      child: const Text('SAVE FUEL FILL-UP'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesStreamProvider).value ?? [];
    if (vehicles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fuel Tracker')),
        body: const Center(child: Text('Add a vehicle first.')),
      );
    }

    final activeVehicle = vehicles.firstWhere(
      (v) => v.id == widget.vehicleId,
      orElse: () => vehicles.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Fuel: ${activeVehicle.make} ${activeVehicle.model}'),
      ),
      body: StreamBuilder<List<FuelLogsTableData>>(
        stream: ref.watch(fuelDaoProvider).watchVehicleFuelLogs(activeVehicle.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: CarLogTheme.primaryCyan));
          }

          final logs = snapshot.data!;
          if (logs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_gas_station_rounded, size: 64, color: CarLogTheme.textMuted.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    const Text('No Fuel Logs Yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CarLogTheme.textMain)),
                    const SizedBox(height: 6),
                    const Text(
                      'Log full-tank fill-ups to automatically compute your exact L / 100 km consumption.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: CarLogTheme.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final log = logs[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CarLogTheme.primaryDarkCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_gas_station_rounded, color: CarLogTheme.primaryCyan, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '\$${log.totalCostUsd.toStringAsFixed(2)} USD',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CarLogTheme.textMain),
                                ),
                                Text(
                                  DateFormat('MMM dd, yyyy').format(log.fillDate),
                                  style: const TextStyle(fontSize: 12, color: CarLogTheme.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${log.fuelLiters} L @ \$${log.pricePerLiterUsd.toStringAsFixed(3)}/L  &bull;  ${log.odometerKm} km',
                              style: const TextStyle(fontSize: 12.5, color: CarLogTheme.textMuted),
                            ),
                            if (log.calculatedLPer100km != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: CarLogTheme.accentGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${log.calculatedLPer100km} L/100km  (${log.calculatedLPer100km! > 0 ? (100 / log.calculatedLPer100km!).toStringAsFixed(1) : '-'} km/L)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: CarLogTheme.accentGreen),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: CarLogTheme.primaryCyan,
        foregroundColor: CarLogTheme.bgDark,
        icon: const Icon(Icons.add_rounded),
        label: const Text('ADD FUEL', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () => _showAddFuelModal(activeVehicle),
      ),
    );
  }
}
