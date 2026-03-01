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
            SizedBox(
              height: 180,
              child: points.length < 2
                  ? Center(
                      child: Text(
                        'Data chart tidak tersedia',
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  : CustomPaint(
                      painter: _LineChartPainter(
                        points: points,
                        lineColor: theme.colorScheme.primary,
                        gridColor: semantic.chartGrid,
                      ),
                      child: const SizedBox.expand(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
  });

  final List<DailyPricePoint> points;
  final Color lineColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 8.0;
    final chartRect = Rect.fromLTWH(
      padding,
      padding,
      math.max(0, size.width - (padding * 2)),
      math.max(0, size.height - (padding * 2)),
    );

    final minClose = points.map((e) => e.close).reduce(math.min);
    final maxClose = points.map((e) => e.close).reduce(math.max);
    final range = math.max(maxClose - minClose, 0.0001);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = chartRect.top + chartRect.height * (i / 3);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final dx = chartRect.left + (chartRect.width * (i / (points.length - 1)));
      final norm = (points[i].close - minClose) / range;
      final dy = chartRect.bottom - (chartRect.height * norm);
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
