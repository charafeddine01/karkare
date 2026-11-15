// =============================================================================
// CarLog Cost-Per-Kilometer ($/km) TCO Analytics Card
// Strictly USD ($) & Metric: Total Spend, Total km, $/km and L/100km
// =============================================================================

import 'package:flutter/material.dart';
import '../data/local/daos/fuel_dao.dart';
import '../core/theme/carlog_theme.dart';

class CostPerKmCard extends StatelessWidget {
  final VehicleTcoAnalytics analytics;

  const CostPerKmCard({super.key, required this.analytics});

  Widget _buildStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CarLogTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CarLogTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: CarLogTheme.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: CarLogTheme.accentGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: CarLogTheme.accentGreen, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'TCO & Cost-Per-Kilometer',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CarLogTheme.textMain),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: CarLogTheme.primaryDarkCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CarLogTheme.primaryCyan),
                  ),
                  child: Text(
                    '\$${analytics.costPerKmUsd.toStringAsFixed(3)} / km',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: CarLogTheme.primaryCyan,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2x2 Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'TOTAL MAINTENANCE',
                    '\$${analytics.totalMaintenanceUsd.toStringAsFixed(2)}',
                    CarLogTheme.textMain,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatBox(
                    'TOTAL FUEL SPEND',
                    '\$${analytics.totalFuelUsd.toStringAsFixed(2)}',
                    CarLogTheme.textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatBox(
                    'DISTANCE TRACKED',
                    '${analytics.totalDistanceKm} km',
                    CarLogTheme.primaryCyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatBox(
                    'AVG CONSUMPTION',
                    analytics.averageLPer100km != null
                        ? '${analytics.averageLPer100km} L/100km'
                        : 'No fuel data',
                    CarLogTheme.accentGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar spend breakdown (Maintenance vs Fuel)
            if (analytics.overallTotalUsd > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Expanded(
                      flex: (analytics.totalMaintenanceUsd * 100).round(),
                      child: Container(height: 6, color: CarLogTheme.primaryCyan),
                    ),
                    Expanded(
                      flex: (analytics.totalFuelUsd * 100).round(),
                      child: Container(height: 6, color: CarLogTheme.accentAmber),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: CarLogTheme.primaryCyan, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Maintenance', style: TextStyle(fontSize: 10.5, color: CarLogTheme.textMuted)),
                    ],
                  ),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: CarLogTheme.accentAmber, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Fuel Fill-ups', style: TextStyle(fontSize: 10.5, color: CarLogTheme.textMuted)),
                    ],
                  ),
                  Text(
                    'Overall: \$${analytics.overallTotalUsd.toStringAsFixed(2)} USD',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CarLogTheme.textMain),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
