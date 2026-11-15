// =============================================================================
// CarLog Main Garage Dashboard Screen
// Offline-First Central Platform: Vehicle Cards, Reminders, Specs, TCO Analytics
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../data/local/database.dart';
import '../../data/local/daos/maintenance_dao.dart';
import '../../data/local/daos/fuel_dao.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/quick_specs_card.dart';
import '../../widgets/cost_per_km_card.dart';
import '../vehicles/add_edit_vehicle_screen.dart';
import '../maintenance/add_service_bundle_screen.dart';
import '../fuel/fuel_tracker_screen.dart';
import '../symptoms/symptom_journal_screen.dart';
import '../inspections/inspection_runner_screen.dart';
import '../inventory/inventory_screen.dart';
import '../export/service_report_export_screen.dart';

class GarageDashboardScreen extends ConsumerStatefulWidget {
  const GarageDashboardScreen({super.key});

  @override
  ConsumerState<GarageDashboardScreen> createState() => _GarageDashboardScreenState();
}

class _GarageDashboardScreenState extends ConsumerState<GarageDashboardScreen> {
  int _selectedNavIndex = 0;

  void _showOdometerUpdateDialog(VehiclesTableData vehicle) {
    final controller = TextEditingController(text: vehicle.currentOdometerKm.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CarLogTheme.surfaceDark,
        title: const Text('Update Current Odometer (km)', style: TextStyle(color: CarLogTheme.textMain)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Weekly Check-in: Enter your latest odometer reading for ${vehicle.year} ${vehicle.make} ${vehicle.model}:',
              style: const TextStyle(fontSize: 13, color: CarLogTheme.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Current Odometer (km)',
                suffixText: 'km',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: CarLogTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKm = int.tryParse(controller.text.trim());
              if (newKm != null && newKm >= vehicle.acquisitionOdometerKm) {
                await ref.read(vehicleDaoProvider).updateCurrentOdometer(vehicle.id, newKm);
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersList(List<TaskReminderStatus> reminders) {
    if (reminders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CarLogTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CarLogTheme.borderDark),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: CarLogTheme.accentGreen, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'All maintenance schedules up to date! No tasks currently overdue.',
                style: TextStyle(fontSize: 13, color: CarLogTheme.textMuted),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: reminders.take(5).map((r) {
        Color badgeColor;
        String statusLabel;
        IconData icon;

        switch (r.urgency) {
          case ReminderUrgency.overdue:
            badgeColor = CarLogTheme.accentRed;
            statusLabel = 'OVERDUE';
            icon = Icons.error_outline_rounded;
            break;
          case ReminderUrgency.dueSoon:
            badgeColor = CarLogTheme.accentAmber;
            statusLabel = 'DUE SOON';
            icon = Icons.warning_amber_rounded;
            break;
          case ReminderUrgency.upcoming:
            badgeColor = CarLogTheme.accentGreen;
            statusLabel = 'UPCOMING';
            icon = Icons.check_circle_outline_rounded;
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: CarLogTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: badgeColor.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, color: badgeColor, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.task.taskName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: CarLogTheme.textMain),
                    ),
                    Text(
                      r.remainingKm != null
                          ? (r.remainingKm! > 0 ? '${r.remainingKm} km remaining' : '${-r.remainingKm!} km past due')
                          : (r.remainingDays != null ? '${r.remainingDays} days' : ''),
                      style: const TextStyle(fontSize: 12, color: CarLogTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesStreamProvider);
    final selectedVehicleId = ref.watch(selectedVehicleIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.directions_car_rounded, color: CarLogTheme.primaryCyan),
            SizedBox(width: 8),
            Text('CarLog Garage'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: CarLogTheme.primaryCyan),
            tooltip: 'Add Vehicle',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditVehicleScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.checklist_rtl_rounded, color: CarLogTheme.primaryCyan),
            tooltip: 'Pre-Trip Inspection',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InspectionRunnerScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Persistent Offline Banner
          const OfflineBanner(),

          Expanded(
            child: vehiclesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: CarLogTheme.primaryCyan)),
              error: (err, _) => Center(child: Text('Error loading garage: $err')),
              data: (vehicles) {
                if (vehicles.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.garage_rounded, size: 72, color: CarLogTheme.textMuted.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          const Text(
                            'Your Garage is Empty',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CarLogTheme.textMain),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your first car, motorcycle, or truck using our 3-Step VIN Decoder & camera OCR.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: CarLogTheme.textMuted),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('ADD VEHICLE TO GARAGE'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AddEditVehicleScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Determine active vehicle
                final activeVehicle = vehicles.firstWhere(
                  (v) => v.id == selectedVehicleId,
                  orElse: () => vehicles.first,
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vehicle Selector Dropdown / Chips
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: CarLogTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CarLogTheme.borderDark),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: activeVehicle.id,
                            isExpanded: true,
                            dropdownColor: CarLogTheme.surfaceDark,
                            icon: const Icon(Icons.arrow_drop_down, color: CarLogTheme.primaryCyan),
                            items: vehicles.map((v) {
                              return DropdownMenuItem<String>(
                                value: v.id,
                                child: Row(
                                  children: [
                                    Icon(
                                      v.vehicleType == 'motorcycle'
                                          ? Icons.two_wheeler_rounded
                                          : Icons.directions_car_rounded,
                                      size: 18,
                                      color: CarLogTheme.primaryCyan,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${v.year} ${v.make} ${v.model} (${v.plateNumber ?? 'No Plate'})',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CarLogTheme.textMain),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (newId) {
                              if (newId != null) {
                                ref.read(selectedVehicleIdProvider.notifier).state = newId;
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Weekly Odometer Update Reminder Banner
                      InkWell(
                        onTap: () => _showOdometerUpdateDialog(activeVehicle),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: CarLogTheme.primaryDarkCyan.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: CarLogTheme.primaryCyan.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.speed_rounded, color: CarLogTheme.primaryCyan, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Current Odometer: ${activeVehicle.currentOdometerKm} km — Tap to update',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CarLogTheme.textMain),
                                ),
                              ),
                              const Icon(Icons.edit_rounded, size: 16, color: CarLogTheme.primaryCyan),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Glovebox Quick-Specs Card
                      StreamBuilder<VehicleQuickSpecsTableData?>(
                        stream: ref.watch(vehicleDaoProvider).watchQuickSpecs(activeVehicle.id),
                        builder: (ctx, snap) {
                          return QuickSpecsCard(
                            specs: snap.data,
                            vehicleType: activeVehicle.vehicleType,
                            onEdit: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddEditVehicleScreen(vehicleIdToEdit: activeVehicle.id),
                                ),
                              );
                            },
                          );
                        },
                      ),

                      // TCO & Cost-Per-Kilometer Card
                      FutureBuilder<VehicleTcoAnalytics>(
                        future: ref.watch(fuelDaoProvider).getVehicleAnalytics(activeVehicle.id),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                          }
                          final analytics = snap.data ??
                              VehicleTcoAnalytics(
                                totalMaintenanceUsd: 0,
                                totalFuelUsd: 0,
                                overallTotalUsd: 0,
                                totalDistanceKm: 0,
                                costPerKmUsd: 0,
                                totalFuelLogs: 0,
                                totalServiceLogs: 0,
                              );
                          return CostPerKmCard(analytics: analytics);
                        },
                      ),

                      // Dual-Trigger Maintenance Reminders Section
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Maintenance Reminders (km + Time)',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CarLogTheme.textMain),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddServiceBundleScreen(vehicleId: activeVehicle.id),
                                ),
                              );
                            },
                            child: const Text('+ Log Service', style: TextStyle(color: CarLogTheme.primaryCyan, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<List<TaskReminderStatus>>(
                        future: ref
                            .watch(maintenanceDaoProvider)
                            .getVehicleReminders(activeVehicle.id, activeVehicle.currentOdometerKm),
                        builder: (ctx, snap) {
                          return _buildRemindersList(snap.data ?? []);
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // Bottom Navigation for Quick Module Switching
      bottomNavigationBar: NavigationBar(
        backgroundColor: CarLogTheme.surfaceDark,
        indicatorColor: CarLogTheme.primaryCyan.withOpacity(0.2),
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (idx) {
          setState(() => _selectedNavIndex = idx);
          final vehicles = ref.read(vehiclesStreamProvider).value ?? [];
          final targetId = ref.read(selectedVehicleIdProvider) ?? (vehicles.isNotEmpty ? vehicles.first.id : null);
          if (idx == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddServiceBundleScreen(vehicleId: targetId)));
          } else if (idx == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FuelTrackerScreen(vehicleId: targetId)));
          } else if (idx == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SymptomJournalScreen(vehicleId: targetId)));
          } else if (idx == 4) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()));
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Garage'),
          NavigationDestination(icon: Icon(Icons.build_rounded), label: 'Service'),
          NavigationDestination(icon: Icon(Icons.local_gas_station_rounded), label: 'Fuel'),
          NavigationDestination(icon: Icon(Icons.healing_rounded), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'Inventory'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: CarLogTheme.primaryCyan,
        foregroundColor: CarLogTheme.bgDark,
        icon: const Icon(Icons.qr_code_2_rounded),
        label: const Text('SHARE & PDF', style: TextStyle(fontWeight: FontWeight.w800)),
        onPressed: () {
          final vehicles = ref.read(vehiclesStreamProvider).value ?? [];
          final targetId = ref.read(selectedVehicleIdProvider) ?? (vehicles.isNotEmpty ? vehicles.first.id : null);
          if (targetId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceReportExportScreen(vehicleId: targetId),
              ),
            );
          }
        },
      ),
    );
  }
}
