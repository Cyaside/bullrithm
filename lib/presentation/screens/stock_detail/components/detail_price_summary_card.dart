import 'package:flutter/material.dart';

import 'detail_formatters.dart';

class StockDetailPriceSummaryCard extends StatelessWidget {
  const StockDetailPriceSummaryCard({
    super.key,
    required this.price,
    required this.currency,
    required this.changeValue,
    required this.changePercent,
    required this.changeColor,
    required this.lastUpdated,
  });

  final double price;
  final String? currency;
  final double changeValue;
  final double changePercent;
  final Color changeColor;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceLabel = price > 0
        ? '${compactCurrencyCode(currency)} ${formatDecimal(price)}'
        : 'Data tidak tersedia';
    final deltaPrefix = changeValue >= 0 ? '+' : '';
    final lastUpdatedLabel = lastUpdated == null
        ? '-'
        : '${lastUpdated!.hour.toString().padLeft(2, '0')}:'
              '${lastUpdated!.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Harga Terakhir', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(priceLabel, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              '$deltaPrefix${formatDecimal(changeValue)} '
              '($deltaPrefix${formatDecimal(changePercent)}%)',
              style: theme.textTheme.titleLarge?.copyWith(color: changeColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: $lastUpdatedLabel',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
