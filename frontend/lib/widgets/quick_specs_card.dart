// =============================================================================
// CarLog Glovebox "Quick-Specs" Reference Card
// Pinned collapsible card storing 100% Metric static vehicle specifications
// =============================================================================

import 'package:flutter/material.dart';
import '../data/local/database.dart';
import '../core/theme/carlog_theme.dart';

class QuickSpecsCard extends StatefulWidget {
  final VehicleQuickSpecsTableData? specs;
  final String vehicleType;
  final VoidCallback onEdit;

  const QuickSpecsCard({
    super.key,
    required this.specs,
    required this.vehicleType,
    required this.onEdit,
  });

  @override
  State<QuickSpecsCard> createState() => _QuickSpecsCardState();
}

class _QuickSpecsCardState extends State<QuickSpecsCard> {
  bool _isExpanded = true;

  Widget _buildSpecRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: CarLogTheme.primaryCyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: CarLogTheme.textMuted),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CarLogTheme.textMain),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final specs = widget.specs;
    final isMoto = widget.vehicleType == 'motorcycle';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CarLogTheme.primaryDarkCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: CarLogTheme.primaryCyan, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Glovebox Quick-Specs',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CarLogTheme.textMain),
                        ),
                        Text(
                          'Metric Reference (100% km, L, Bar, mm)',
                          style: TextStyle(fontSize: 11, color: CarLogTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: CarLogTheme.primaryCyan),
                    onPressed: widget.onEdit,
                    tooltip: 'Edit Quick Specs',
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: CarLogTheme.textMuted,
                  ),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 12),
              const Divider(color: CarLogTheme.borderDark),
              const SizedBox(height: 8),
              if (specs == null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No quick specs recorded yet. Tap edit to enter oil viscosities, tire pressures, torque & fluids.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: CarLogTheme.textMuted),
                  ),
                ),
              ] else ...[
                if (specs.oilViscosity != null || specs.oilCapacityL != null)
                  _buildSpecRow(
                    'Engine Oil',
                    '${specs.oilViscosity ?? 'Spec N/A'} (${specs.oilCapacityL != null ? '${specs.oilCapacityL} L' : '-'})',
                    Icons.opacity_rounded,
                  ),
                if (specs.coolantSpec != null || specs.coolantCapacityL != null)
                  _buildSpecRow(
                    'Coolant Flush',
                    '${specs.coolantSpec ?? 'N/A'} (${specs.coolantCapacityL != null ? '${specs.coolantCapacityL} L' : '-'})',
                    Icons.waves_rounded,
                  ),
                if (specs.frontTirePressureBar != null || specs.rearTirePressureBar != null)
                  _buildSpecRow(
                    'Tire Pressure',
                    'F: ${specs.frontTirePressureBar ?? '-'} Bar  |  R: ${specs.rearTirePressureBar ?? '-'} Bar',
                    Icons.speed_rounded,
                  ),
                if (specs.wheelLugTorqueNm != null)
                  _buildSpecRow(
                    'Lug Nut Torque',
                    '${specs.wheelLugTorqueNm} Nm',
                    Icons.build_circle_outlined,
                  ),
                if (!isMoto && (specs.wiperDriverMm != null || specs.wiperPassengerMm != null))
                  _buildSpecRow(
                    'Wiper Blades',
                    'D: ${specs.wiperDriverMm ?? '-'} mm  |  P: ${specs.wiperPassengerMm ?? '-'} mm',
                    Icons.water_drop_outlined,
                  ),
                if (specs.batterySpec != null)
                  _buildSpecRow(
                    'Battery Spec',
                    specs.batterySpec!,
                    Icons.battery_charging_full_rounded,
                  ),
                if (specs.sparkPlugGapMm != null)
                  _buildSpecRow(
                    'Spark Plug Gap',
                    '${specs.sparkPlugGapMm} mm',
                    Icons.bolt_rounded,
                  ),
                if (isMoto && specs.chainPitchMm != null)
                  _buildSpecRow(
                    'Drive Chain Pitch',
                    specs.chainPitchMm!,
                    Icons.link_rounded,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
