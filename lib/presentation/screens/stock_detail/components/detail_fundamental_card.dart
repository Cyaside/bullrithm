import 'package:flutter/material.dart';

import '../../../../common/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import 'detail_formatters.dart';

class StockDetailFundamentalCard extends StatelessWidget {
  const StockDetailFundamentalCard({super.key, required this.overview});

  final CompanyOverview? overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <_MetricItem>[
      _MetricItem(
        'Market Cap',
        formatMarketCap(overview?.marketCapitalization),
      ),
      _MetricItem('Sector', displayOrFallback(overview?.sector)),
      _MetricItem('Industry', displayOrFallback(overview?.industry)),
      _MetricItem(
        'P/E Ratio',
        overview?.peRatio == null
            ? 'Data tidak tersedia'
            : formatDecimal(overview!.peRatio!),
      ),
      _MetricItem('Currency', displayOrFallback(overview?.currency)),
      _MetricItem('Country', displayOrFallback(overview?.country)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fundamental', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: context.semanticColors.surfaceMuted,
                    border: Border.all(color: context.semanticColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(item.label, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        item.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value);

  final String label;
  final String value;
}
