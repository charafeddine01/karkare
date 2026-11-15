// =============================================================================
// CarLog Interactive 4-Wheel / 2-Wheel Position Selector
// Car/Truck: FL, FR, RL, RR + Spare | Motorcycle: Front, Rear
// =============================================================================

import 'package:flutter/material.dart';
import '../core/theme/carlog_theme.dart';

class WheelSelectionData {
  final Set<String> selectedPositions;
  final String? tireDotCode;
  final double? measurementMm; // Tread depth or pad thickness in mm

  WheelSelectionData({
    required this.selectedPositions,
    this.tireDotCode,
    this.measurementMm,
  });
}

class WheelSelectorWidget extends StatefulWidget {
  final String vehicleType; // 'car', 'motorcycle', 'truck'
  final Set<String> initialSelected;
  final String? initialDot;
  final double? initialMeasurementMm;
  final ValueChanged<WheelSelectionData> onChanged;

  const WheelSelectorWidget({
    super.key,
    required this.vehicleType,
    this.initialSelected = const {},
    this.initialDot,
    this.initialMeasurementMm,
    required this.onChanged,
  });

  @override
  State<WheelSelectorWidget> createState() => _WheelSelectorWidgetState();
}

class _WheelSelectorWidgetState extends State<WheelSelectorWidget> {
  late Set<String> _selected;
  late TextEditingController _dotController;
  late TextEditingController _measurementController;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.initialSelected);
    _dotController = TextEditingController(text: widget.initialDot ?? '');
    _measurementController = TextEditingController(
      text: widget.initialMeasurementMm != null ? widget.initialMeasurementMm.toString() : '',
    );
  }

  @override
  void dispose() {
    _dotController.dispose();
    _measurementController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      WheelSelectionData(
        selectedPositions: _selected,
        tireDotCode: _dotController.text.trim().isNotEmpty ? _dotController.text.trim() : null,
        measurementMm: double.tryParse(_measurementController.text.trim()),
      ),
    );
  }

  void _togglePosition(String pos) {
    setState(() {
      if (_selected.contains(pos)) {
        _selected.remove(pos);
      } else {
        _selected.add(pos);
      }
    });
    _notify();
  }

  Widget _buildWheelBox(String code, String label) {
    final isSelected = _selected.contains(code);
    return GestureDetector(
      onTap: () => _togglePosition(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 68,
        height: 72,
        decoration: BoxDecoration(
          color: isSelected ? CarLogTheme.primaryCyan.withOpacity(0.18) : CarLogTheme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? CarLogTheme.primaryCyan : CarLogTheme.borderDark,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CarLogTheme.primaryCyan.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.album_outlined,
              size: 26,
              color: isSelected ? CarLogTheme.primaryCyan : CarLogTheme.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              code,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? CarLogTheme.primaryCyan : CarLogTheme.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMoto = widget.vehicleType == 'motorcycle';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CarLogTheme.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CarLogTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isMoto ? 'Wheel Position (2-Wheel Layout)' : 'Wheel Position (4-Wheel + Spare)',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CarLogTheme.textMain),
              ),
              if (_selected.isNotEmpty)
                Text(
                  _selected.join(', '),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CarLogTheme.primaryCyan),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Visual Interactive Diagram
          if (isMoto)
            Center(
              child: Column(
                children: [
                  _buildWheelBox('Front', 'Front Wheel'),
                  const SizedBox(height: 12),
                  Container(width: 4, height: 28, color: CarLogTheme.borderDark),
                  const SizedBox(height: 12),
                  _buildWheelBox('Rear', 'Rear Wheel'),
                ],
              ),
            )
          else
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildWheelBox('FL', 'Front Left'),
                    const SizedBox(width: 40),
                    _buildWheelBox('FR', 'Front Right'),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: 140,
                  height: 30,
                  decoration: BoxDecoration(
                    color: CarLogTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CarLogTheme.borderDark),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'CHASSIS AXLE',
                    style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: CarLogTheme.textMuted, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildWheelBox('RL', 'Rear Left'),
                    const SizedBox(width: 40),
                    _buildWheelBox('RR', 'Rear Right'),
                  ],
                ),
                const SizedBox(height: 14),
                Center(child: _buildWheelBox('Spare', 'Spare Tire')),
              ],
            ),

          const SizedBox(height: 20),
          const Divider(color: CarLogTheme.borderDark),
          const SizedBox(height: 12),

          // DOT Code & Measurement (mm) inputs
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dotController,
                  onChanged: (_) => _notify(),
                  decoration: const InputDecoration(
                    labelText: 'Tire DOT Code',
                    hintText: 'e.g. 2321',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _measurementController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _notify(),
                  decoration: const InputDecoration(
                    labelText: 'Measurement (mm)',
                    hintText: 'Tread/Pad mm',
                    isDense: true,
                    suffixText: 'mm',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
