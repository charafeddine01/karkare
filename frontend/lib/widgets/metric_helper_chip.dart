// =============================================================================
// CarLog Inline Metric Helper Chip
// Instant conversion from Imperial specs to strict Metric units
// =============================================================================

import 'package:flutter/material.dart';
import '../core/utils/imperial_metric_converter.dart';
import '../core/theme/carlog_theme.dart';

enum MetricConversionType {
  psiToBar,
  quartsToLiters,
  lbFtToNm,
  inchesToMm,
  gallonsToLiters,
  milesToKm,
  hpToKw,
  ciToCc,
}

class MetricHelperChip extends StatelessWidget {
  final TextEditingController controller;
  final MetricConversionType type;
  final String label;

  const MetricHelperChip({
    super.key,
    required this.controller,
    required this.type,
    required this.label,
  });

  void _convert() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final val = double.tryParse(text);
    if (val == null) return;

    String result;
    switch (type) {
      case MetricConversionType.psiToBar:
        result = ImperialMetricConverter.psiToBar(val).toString();
        break;
      case MetricConversionType.quartsToLiters:
        result = ImperialMetricConverter.quartsToLiters(val).toString();
        break;
      case MetricConversionType.lbFtToNm:
        result = ImperialMetricConverter.lbFtToNm(val).toString();
        break;
      case MetricConversionType.inchesToMm:
        result = ImperialMetricConverter.inchesToMm(val).toString();
        break;
      case MetricConversionType.gallonsToLiters:
        result = ImperialMetricConverter.gallonsToLiters(val).toString();
        break;
      case MetricConversionType.milesToKm:
        result = ImperialMetricConverter.milesToKm(val).toString();
        break;
      case MetricConversionType.hpToKw:
        result = ImperialMetricConverter.hpToKw(val).toString();
        break;
      case MetricConversionType.ciToCc:
        result = ImperialMetricConverter.ciToCc(val).toString();
        break;
    }

    controller.text = result;
    controller.selection = TextSelection.fromPosition(TextPosition(offset: result.length));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _convert,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: CarLogTheme.primaryDarkCyan.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: CarLogTheme.primaryCyan.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz_rounded, size: 14, color: CarLogTheme.primaryCyan),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: CarLogTheme.primaryCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
