// =============================================================================
// CarLog Pre-Trip / Seasonal Inspection Checklists Runner
// Templates: Pre-Road Trip, Winter Readiness, Motorcycle Pre-Ride (T-CLOCS)
// Automatically converts 'Needs Attention' items into dashboard reminders!
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../data/local/daos/maintenance_dao.dart';
import '../../core/network/toast_service.dart';

class InspectionItem {
  final String id;
  final String title;
  final String category;
  final String hint;
  String status; // 'pass', 'attention', 'fail', 'unchecked'

  InspectionItem({
    required this.id,
    required this.title,
    required this.category,
    required this.hint,
    this.status = 'unchecked',
  });
}

class InspectionRunnerScreen extends ConsumerStatefulWidget {
  const InspectionRunnerScreen({super.key});

  @override
  ConsumerState<InspectionRunnerScreen> createState() => _InspectionRunnerScreenState();
}

class _InspectionRunnerScreenState extends ConsumerState<InspectionRunnerScreen> {
  String _selectedTemplate = 'road_trip';
  late List<InspectionItem> _currentChecklist;

  @override
  void initState() {
    super.initState();
    _loadTemplate(_selectedTemplate);
  }

  void _loadTemplate(String key) {
    setState(() {
      _selectedTemplate = key;
      if (key == 'road_trip') {
        _currentChecklist = [
          InspectionItem(id: 'rt_1', title: 'Tire Pressures (Cold) & Tread', category: 'Tires & Wheels', hint: 'Check all 4 tires + spare against door jamb Bar spec'),
          InspectionItem(id: 'rt_2', title: 'Engine Oil Dipstick Level', category: 'Fluids', hint: 'Warm engine, wipe dipstick, confirm level is between MIN and MAX'),
          InspectionItem(id: 'rt_3', title: 'Coolant Level & Hoses', category: 'Fluids', hint: 'Inspect reservoir tank and radiator upper/lower hoses for cracks'),
          InspectionItem(id: 'rt_4', title: 'Brake Fluid Reservoir', category: 'Brakes', hint: 'Transparent reservoir should be near MAX with clear golden fluid'),
          InspectionItem(id: 'rt_5', title: 'Exterior Lights & Turn Signals', category: 'Electrical', hint: 'High/low beams, brake lights, hazard lights, reverse light'),
          InspectionItem(id: 'rt_6', title: 'Windshield Washer Fluid & Wipers', category: 'Visibility', hint: 'Top up fluid; inspect rubber blade edge for tearing'),
          InspectionItem(id: 'rt_7', title: 'Emergency Jack & Lug Wrench', category: 'Safety', hint: 'Ensure scissor jack, lug wrench, and warning triangle are present'),
        ];
      } else if (key == 'winter') {
        _currentChecklist = [
          InspectionItem(id: 'w_1', title: '12V Battery Health & CCA Test', category: 'Electrical', hint: 'Clean terminals; ensure resting voltage is >= 12.6V'),
          InspectionItem(id: 'w_2', title: 'Antifreeze Concentration', category: 'Cooling', hint: 'Hydrometer test: ensure protection down to -25°C or -30°C'),
          InspectionItem(id: 'w_3', title: 'Winter / All-Weather Tires Tread', category: 'Tires & Wheels', hint: 'Minimum recommended winter tread depth is 4.0 mm'),
          InspectionItem(id: 'w_4', title: 'Cabin Heating & Defroster', category: 'HVAC', hint: 'Test front windshield defroster and rear electric heating grid'),
          InspectionItem(id: 'w_5', title: 'Sub-Zero Windshield Fluid (-20°C)', category: 'Visibility', hint: 'Replace summer bug-wash with winter de-icing formula'),
          InspectionItem(id: 'w_6', title: 'Door Weatherstripping Silicone Lube', category: 'Body', hint: 'Apply silicone grease to prevent doors freezing shut'),
        ];
      } else {
        // Motorcycle Pre-Ride (T-CLOCS)
        _currentChecklist = [
          InspectionItem(id: 'm_1', title: 'Tires: Air Pressure & Tread', category: 'Tires', hint: 'Front/rear cold pressure; check for nails and embedded gravel'),
          InspectionItem(id: 'm_2', title: 'Controls: Throttle & Clutch Freeplay', category: 'Controls', hint: 'Throttle snaps back immediately; clutch cable smooth with 2-3mm play'),
          InspectionItem(id: 'm_3', title: 'Brakes: Front Lever & Rear Pedal Firmness', category: 'Brakes', hint: 'No sponginess; inspect pad thickness in calipers'),
          InspectionItem(id: 'm_4', title: 'Lights & Electrics: Headlight & Brake', category: 'Electrical', hint: 'Check brake light activation on BOTH hand lever and foot pedal'),
          InspectionItem(id: 'm_5', title: 'Oil Sight Glass Level', category: 'Fluids', hint: 'Hold bike upright on level ground; oil must sit between indicator lines'),
          InspectionItem(id: 'm_6', title: 'Chassis & Drive Chain Slack (25-35mm)', category: 'Drivetrain', hint: 'Clean/lube chain; measure mid-span vertical chain slack'),
          InspectionItem(id: 'm_7', title: 'Side Stand Cut-off Switch', category: 'Safety', hint: 'Engine cuts off when in gear with side stand down'),
        ];
      }
    });
  }

  Future<void> _completeInspection() async {
    final attentionItems = _currentChecklist.where((i) => i.status == 'attention' || i.status == 'fail').toList();
    final vehicles = ref.read(vehiclesStreamProvider).value ?? [];
    if (vehicles.isEmpty) return;

    final selectedVehicleId = ref.read(selectedVehicleIdProvider);
    final activeVehicle = vehicles.firstWhere((v) => v.id == selectedVehicleId, orElse: () => vehicles.first);

    // Auto-create service reminders for items needing attention
    if (attentionItems.isNotEmpty) {
      final items = attentionItems.map((item) {
        return ServiceBundleItemInput(
          taskId: '10000000-0000-0000-0000-000000000001', // Attached to checkup
          notes: 'Flagged during ${_selectedTemplate.toUpperCase()} Inspection: ${item.title} (${item.hint})',
          nextDueKm: activeVehicle.currentOdometerKm + 500, // Due soon within 500 km
          nextDueDate: DateTime.now().add(const Duration(days: 7)),
        );
      }).toList();

      await ref.read(maintenanceDaoProvider).logServiceBundle(
        vehicleId: activeVehicle.id,
        serviceDate: DateTime.now(),
        odometerKm: activeVehicle.currentOdometerKm,
        visitTitle: '${_selectedTemplate.toUpperCase()} Checklist Inspection Flags',
        generalNotes: '${attentionItems.length} items flagged as needing attention.',
        items: items,
      );

      ref.invalidate(vehiclesStreamProvider);

      ToastService.show(
        'Inspection completed! Created ${attentionItems.length} pending reminders on dashboard.',
        type: ToastType.warning,
      );
    } else {
      ToastService.show('Inspection 100% Passed! Vehicle is road-ready.', type: ToastType.success);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final passedCount = _currentChecklist.where((i) => i.status == 'pass').length;
    final totalCount = _currentChecklist.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety & Seasonal Inspection'),
      ),
      body: Column(
        children: [
          // Template Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: CarLogTheme.surfaceDark,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Road Trip'),
                  selected: _selectedTemplate == 'road_trip',
                  onSelected: (val) => val ? _loadTemplate('road_trip') : null,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Winter Readiness'),
                  selected: _selectedTemplate == 'winter',
                  onSelected: (val) => val ? _loadTemplate('winter') : null,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Moto Pre-Ride'),
                  selected: _selectedTemplate == 'motorcycle',
                  onSelected: (val) => val ? _loadTemplate('motorcycle') : null,
                ),
              ],
            ),
          ),

          // Progress Bar
          LinearProgressIndicator(
            value: totalCount > 0 ? passedCount / totalCount : 0.0,
            backgroundColor: CarLogTheme.surfaceCard,
            valueColor: const AlwaysStoppedAnimation(CarLogTheme.accentGreen),
            minHeight: 4,
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _currentChecklist.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final item = _currentChecklist[i];

                Color borderColor;
                if (item.status == 'pass') {
                  borderColor = CarLogTheme.accentGreen;
                } else if (item.status == 'attention') {
                  borderColor = CarLogTheme.accentAmber;
                } else if (item.status == 'fail') {
                  borderColor = CarLogTheme.accentRed;
                } else {
                  borderColor = CarLogTheme.borderDark;
                }

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CarLogTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: item.status != 'unchecked' ? 1.5 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CarLogTheme.textMain),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.hint,
                                  style: const TextStyle(fontSize: 12, color: CarLogTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Status Buttons: Pass, Needs Attention, Fail
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: item.status == 'pass' ? CarLogTheme.accentGreen.withOpacity(0.2) : Colors.transparent,
                                side: BorderSide(color: item.status == 'pass' ? CarLogTheme.accentGreen : CarLogTheme.borderDark),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.check, size: 16, color: CarLogTheme.accentGreen),
                              label: const Text('OK / Pass', style: TextStyle(fontSize: 12, color: CarLogTheme.textMain)),
                              onPressed: () => setState(() => item.status = 'pass'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: item.status == 'attention' ? CarLogTheme.accentAmber.withOpacity(0.2) : Colors.transparent,
                                side: BorderSide(color: item.status == 'attention' ? CarLogTheme.accentAmber : CarLogTheme.borderDark),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.warning_amber_rounded, size: 16, color: CarLogTheme.accentAmber),
                              label: const Text('Attention', style: TextStyle(fontSize: 12, color: CarLogTheme.textMain)),
                              onPressed: () => setState(() => item.status = 'attention'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: item.status == 'fail' ? CarLogTheme.accentRed.withOpacity(0.2) : Colors.transparent,
                                side: BorderSide(color: item.status == 'fail' ? CarLogTheme.accentRed : CarLogTheme.borderDark),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.close_rounded, size: 16, color: CarLogTheme.accentRed),
                              label: const Text('Defective', style: TextStyle(fontSize: 12, color: CarLogTheme.textMain)),
                              onPressed: () => setState(() => item.status = 'fail'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Complete Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: CarLogTheme.surfaceDark,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _completeInspection,
              child: Text('COMPLETE INSPECTION ($passedCount / $totalCount PASSED)'),
            ),
          ),
        ],
      ),
    );
  }
}
