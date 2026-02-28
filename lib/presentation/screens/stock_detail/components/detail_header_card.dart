import 'package:flutter/material.dart';

import '../../../../data/models/models.dart';
import 'detail_formatters.dart';

class StockDetailHeaderCard extends StatelessWidget {
  const StockDetailHeaderCard({
    super.key,
    required this.overview,
    required this.symbol,
  });

  final CompanyOverview? overview;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = displayOrFallback(overview?.name);
    final exchange = displayOrFallback(overview?.exchange);
    final country = displayOrFallback(overview?.country);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(symbol.toUpperCase(), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(displayName, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('$exchange | $country', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
