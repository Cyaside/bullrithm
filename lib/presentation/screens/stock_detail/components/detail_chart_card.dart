import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../common/theme/app_theme.dart';
import '../../../../data/models/models.dart';

class StockDetailChartCard extends StatelessWidget {
  const StockDetailChartCard({super.key, required this.points});

  final List<DailyPricePoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price Chart (30D)', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (points.length < 2)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    'Data chart tidak tersedia',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else
              _BarChart(
                values: _compressPoints(points),
                activeColor: theme.colorScheme.primary,
                passiveColor: semantic.surfaceMuted,
                borderColor: semantic.border,
              ),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.values,
    required this.activeColor,
    required this.passiveColor,
    required this.borderColor,
  });

  final List<double> values;
  final Color activeColor;
  final Color passiveColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final range = math.max(maxValue - minValue, 0.0001);

    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final value = entry.value;
              final normalized = ((value - minValue) / range).clamp(0.0, 1.0);
              final barHeight = 28.0 + (72.0 * normalized);
              final isActive = index == values.length - 1;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: isActive ? activeColor : passiveColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

List<double> _compressPoints(List<DailyPricePoint> points) {
  const targetBars = 8;
  if (points.length <= targetBars) {
    return points.map((point) => point.close).toList(growable: false);
  }

  final bucketSize = points.length / targetBars;
  final values = <double>[];

  for (var i = 0; i < targetBars; i++) {
    final start = (i * bucketSize).floor();
    final end = math.min(points.length, ((i + 1) * bucketSize).ceil());
    final bucket = points.sublist(start, end);
    final average =
        bucket.map((item) => item.close).reduce((a, b) => a + b) /
        bucket.length;
    values.add(average);
  }

  return values;
}
