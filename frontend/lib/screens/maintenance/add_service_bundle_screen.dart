// =============================================================================
// CarLog Add Smart Service Bundle Screen
// Multi-Task Workshop Visit, 3-Tier Part Suggestions & 4-Wheel Diagram
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../data/local/database.dart';
import '../../data/local/daos/maintenance_dao.dart';
import '../../widgets/wheel_selector.dart';
import '../../widgets/ocr_scan_button.dart';
import '../../widgets/metric_helper_chip.dart';
import '../../core/network/toast_service.dart';

class ServiceTaskDraft {
  String taskId;
  String taskName;
  String category;
  double costPartsUsd;
  double costLaborUsd;
  String? partBrand;
  String? partNumber;
  double? fluidVolumeL;
  Set<String> wheelPositions;
  String? tireDotCode;
  double? measurementMm;
  DateTime? warrantyExpiresDate;
  int? nextDueKm;
  DateTime? nextDueDate;
  String? notes;
  String? inventoryIdToConsume;

  ServiceTaskDraft({
    required this.taskId,
    required this.taskName,
    required this.category,
    this.costPartsUsd = 0.0,
    this.costLaborUsd = 0.0,
    this.partBrand,
    this.partNumber,
    this.fluidVolumeL,
    this.wheelPositions = const {},
    this.tireDotCode,
    this.measurementMm,
    this.warrantyExpiresDate,
    this.nextDueKm,
    this.nextDueDate,
    this.notes,
    this.inventoryIdToConsume,
  });
}

class AddServiceBundleScreen extends ConsumerStatefulWidget {
  final String? vehicleId;

  const AddServiceBundleScreen({super.key, this.vehicleId});

  @override
  ConsumerState<AddServiceBundleScreen> createState() => _AddServiceBundleScreenState();
}

class _AddServiceBundleScreenState extends ConsumerState<AddServiceBundleScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedVehicleId;
  DateTime _serviceDate = DateTime.now();
  final _odometerController = TextEditingController();
  final _visitTitleController = TextEditingController(text: 'Routine Service Visit');
  final _notesController = TextEditingController();
  String? _selectedContactId;

  final List<ServiceTaskDraft> _taskDrafts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.vehicleId;
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _visitTitleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _addTaskModal(VehiclesTableData vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CarLogTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StreamBuilder<List<MaintenanceTasksTemplateTableData>>(
          stream: ref.watch(maintenanceDaoProvider).watchTasks(vehicle.vehicleType),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
            }

            final tasks = snapshot.data!;
            // Group by category
            final Map<String, List<MaintenanceTasksTemplateTableData>> categories = {};
            for (final t in tasks) {
              categories.putIfAbsent(t.category, () => []).add(t);
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Maintenance Task',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CarLogTheme.textMain),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: CarLogTheme.textMuted),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...categories.entries.map((cat) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              cat.key.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: CarLogTheme.primaryCyan,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          ...cat.value.map((t) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(t.taskName, style: const TextStyle(color: CarLogTheme.textMain, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                t.defaultIntervalKm != null ? 'Interval: Every ${t.defaultIntervalKm} km' : 'Inspect as needed',
                                style: const TextStyle(fontSize: 11, color: CarLogTheme.textMuted),
                              ),
                              trailing: const Icon(Icons.add_circle_outline, color: CarLogTheme.primaryCyan, size: 20),
                              onTap: () {
                                Navigator.pop(ctx);
                                _addTaskDraft(t, vehicle);
                              },
                            );
                          }),
                          const Divider(color: CarLogTheme.borderDark),
                        ],
                      );
                    }),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _addTaskDraft(MaintenanceTasksTemplateTableData task, VehiclesTableData vehicle) {
    int? nextKm;
    if (task.defaultIntervalKm != null) {
      final currentKm = int.tryParse(_odometerController.text) ?? vehicle.currentOdometerKm;
      nextKm = currentKm + task.defaultIntervalKm!;
    }

    DateTime? nextDate;
    if (task.defaultIntervalMonths != null) {
      nextDate = DateTime.now().add(Duration(days: task.defaultIntervalMonths! * 30));
    }

    setState(() {
      _taskDrafts.add(
        ServiceTaskDraft(
          taskId: task.id,
          taskName: task.taskName,
          category: task.category,
          nextDueKm: nextKm,
          nextDueDate: nextDate,
        ),
      );
    });
  }

  Future<void> _submitServiceBundle(VehiclesTableData vehicle) async {
    if (!_formKey.currentState!.validate()) return;
    if (_taskDrafts.isEmpty) {
      ToastService.show('Please attach at least one maintenance task to this visit.', type: ToastType.warning);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final odoKm = int.parse(_odometerController.text.trim());
      final items = _taskDrafts.map((d) {
        return ServiceBundleItemInput(
          taskId: d.taskId,
          costPartsUsd: d.costPartsUsd,
          costLaborUsd: d.costLaborUsd,
          partBrand: d.partBrand,
          partNumber: d.partNumber,
          fluidVolumeL: d.fluidVolumeL,
          wheelPositions: d.wheelPositions.isNotEmpty ? d.wheelPositions.join(',') : null,
          tireDotCode: d.tireDotCode,
          measurementMm: d.measurementMm,
          warrantyExpiresDate: d.warrantyExpiresDate,
          notes: d.notes,
          nextDueKm: d.nextDueKm,
          nextDueDate: d.nextDueDate,
        );
      }).toList();

      await ref.read(maintenanceDaoProvider).logServiceBundle(
        vehicleId: vehicle.id,
        contactId: _selectedContactId,
        serviceDate: _serviceDate,
        odometerKm: odoKm,
        visitTitle: _visitTitleController.text.trim(),
        generalNotes: _notesController.text.trim(),
        items: items,
      );

      // Consume inventory if linked
      for (final d in _taskDrafts) {
        if (d.inventoryIdToConsume != null) {
          final amt = d.fluidVolumeL ?? 1.0;
          await ref.read(inventoryDaoProvider).consumePartQuantity(d.inventoryIdToConsume!, amt);
        }
      }

      ref.invalidate(vehiclesStreamProvider);

      if (mounted) {
        ToastService.show('Service Bundle logged locally! Reminders & Odometer updated.', type: ToastType.success);
        Navigator.pop(context);
      }
    } catch (e) {
      ToastService.show('Failed to log service visit: $e', type: ToastType.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDraftItemCard(ServiceTaskDraft draft, int index, VehiclesTableData vehicle) {
    final isTireOrBrake = draft.category.contains('Tires') || draft.category.contains('Brakes');
    final isFluid = draft.category.contains('Fluids') || draft.taskName.contains('Oil') || draft.taskName.contains('Coolant');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CarLogTheme.primaryCyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          draft.category.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: CarLogTheme.primaryCyan),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        draft.taskName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CarLogTheme.textMain),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: CarLogTheme.accentRed, size: 20),
                  onPressed: () => setState(() => _taskDrafts.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tier 1 & Tier 2 Part Number Suggestions Chips
            FutureBuilder<Map<String, String>?>(
              future: ref.read(maintenanceDaoProvider).getTier1PartSuggestion(
                    vehicleId: vehicle.id,
                    taskId: draft.taskId,
                  ),
              builder: (ctx, snap) {
                final tier1 = snap.data;
                if (tier1 != null && (draft.partNumber == null || draft.partNumber!.isEmpty)) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 16, color: CarLogTheme.primaryCyan),
                      label: Text(
                        'Tier 1 Memory: ${tier1['part_brand']} ${tier1['part_number']} (${tier1['badge']})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CarLogTheme.primaryCyan),
                      ),
                      onPressed: () {
                        setState(() {
                          draft.partBrand = tier1['part_brand'];
                          draft.partNumber = tier1['part_number'];
                        });
                        ToastService.show('Applied previously used part: ${tier1['part_number']}', type: ToastType.info);
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Part Brand & Part Number Fields + OCR Button
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.partBrand,
                    decoration: const InputDecoration(labelText: 'Part Brand', hintText: 'e.g. Bosch, Brembo, Motul', isDense: true),
                    onChanged: (v) => draft.partBrand = v.trim(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.partNumber,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Part Number',
                      hintText: 'e.g. W 68/3',
                      isDense: true,
                      suffixIcon: OcrScanButton(
                        scanType: OcrScanType.partNumber,
                        onTextRecognized: (text) {
                          setState(() {
                            draft.partNumber = text.toUpperCase();
                          });
                        },
                      ),
                    ),
                    onChanged: (v) => draft.partNumber = v.trim().toUpperCase(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Costs in USD (Parts & Labor)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Parts Cost (\$ USD)', prefixText: '\$ ', isDense: true),
                    onChanged: (v) => draft.costPartsUsd = double.tryParse(v) ?? 0.0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Labor Cost (\$ USD)', prefixText: '\$ ', isDense: true),
                    onChanged: (v) => draft.costLaborUsd = double.tryParse(v) ?? 0.0,
                  ),
                ),
              ],
            ),

            if (isFluid) ...[
              const SizedBox(height: 10),
              TextFormField(
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fluid Volume (Liters)', suffixText: 'L', isDense: true),
                onChanged: (v) => draft.fluidVolumeL = double.tryParse(v),
              ),
            ],

            // Interactive 4-Wheel / 2-Wheel Diagram for Tires/Brakes
            if (isTireOrBrake) ...[
              const SizedBox(height: 16),
              WheelSelectorWidget(
                vehicleType: vehicle.vehicleType,
                initialSelected: draft.wheelPositions,
                initialDot: draft.tireDotCode,
                initialMeasurementMm: draft.measurementMm,
                onChanged: (data) {
                  draft.wheelPositions = data.selectedPositions;
                  draft.tireDotCode = data.tireDotCode;
                  draft.measurementMm = data.measurementMm;
                },
              ),
            ],

            const SizedBox(height: 12),
            // Next Due Km & Notes
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.nextDueKm?.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Next Due (km)', suffixText: 'km', isDense: true),
                    onChanged: (v) => draft.nextDueKm = int.tryParse(v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Task Notes', hintText: 'Warranty, torques...', isDense: true),
                    onChanged: (v) => draft.notes = v.trim(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesStreamProvider).value ?? [];
    if (vehicles.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Log Service Visit')),
        body: const Center(child: Text('Please add a vehicle to your garage first.')),
      );
    }

    final activeVehicle = vehicles.firstWhere(
      (v) => v.id == _selectedVehicleId,
      orElse: () => vehicles.first,
    );

    if (_odometerController.text.isEmpty) {
      _odometerController.text = activeVehicle.currentOdometerKm.toString();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Service Bundle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: CarLogTheme.primaryCyan),
            onPressed: _isLoading ? null : () => _submitServiceBundle(activeVehicle),
            tooltip: 'Save Visit',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: CarLogTheme.primaryCyan))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Visit Header Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CarLogTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CarLogTheme.borderDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${activeVehicle.year} ${activeVehicle.make} ${activeVehicle.model}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CarLogTheme.textMain),
                          ),
                          const SizedBox(height: 14),

                          // Visit Title & Date
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _visitTitleController,
                                  decoration: const InputDecoration(labelText: 'Visit Title', isDense: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: const BorderSide(color: CarLogTheme.borderDark),
                                  ),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _serviceDate,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) setState(() => _serviceDate = picked);
                                  },
                                  child: Text(
                                    DateFormat('MMM dd').format(_serviceDate),
                                    style: const TextStyle(color: CarLogTheme.textMain, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Odometer Reading
                          TextFormField(
                            controller: _odometerController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Visit Odometer Reading *', suffixText: 'km', isDense: true),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Attached Maintenance Tasks
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Attached Tasks (${_taskDrafts.length})',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CarLogTheme.textMain),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('ADD TASK'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () => _addTaskModal(activeVehicle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_taskDrafts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: CarLogTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CarLogTheme.borderDark, style: BorderStyle.solid),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'No maintenance tasks attached yet.\nTap "+ ADD TASK" to log oil change, brakes, filters, etc.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: CarLogTheme.textMuted),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _taskDrafts.length,
                        itemBuilder: (ctx, i) => _buildDraftItemCard(_taskDrafts[i], i, activeVehicle),
                      ),

                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _isLoading ? null : () => _submitServiceBundle(activeVehicle),
                      child: const Text('SAVE COMPLETE SERVICE VISIT'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
