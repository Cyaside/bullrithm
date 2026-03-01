import 'package:flutter/material.dart';

import '../../../../data/models/models.dart';
import 'detail_formatters.dart';

class StockDetailHeaderCard extends StatelessWidget {
  const StockDetailHeaderCard({
    super.key,
    required this.overview,
    required this.symbol,
    required this.price,
    required this.currency,
    required this.changeValue,
    required this.changePercent,
    required this.changeColor,
  });

  final CompanyOverview? overview;
  final String symbol;
  final double price;
  final String? currency;
  final double changeValue;
  final double changePercent;
  final Color changeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = displayOrFallback(overview?.name);
    final priceLabel = price > 0
        ? '\$${formatDecimal(price)}'
        : 'Data tidak tersedia';
    final isUp = changeValue >= 0;
    final deltaPrefix = isUp ? '+' : '';
    final changeLabel = '$deltaPrefix${formatDecimal(changePercent)}%';
    final directionIcon = isUp
        ? Icons.north_east_rounded
        : Icons.south_east_rounded;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    symbol.toUpperCase(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(
                        alpha: 0.86,
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(directionIcon, size: 14, color: changeColor),
                    const SizedBox(width: 3),
                    Text(
                      changeLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  compactCurrencyCode(currency),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
