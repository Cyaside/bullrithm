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
      _MetricItem(
        'P/E Ratio',
        overview?.peRatio == null
            ? 'Data tidak tersedia'
            : formatDecimal(overview!.peRatio!),
      ),
      _MetricItem('Div Yield', formatDividendYield(overview?.dividendYield)),
      _MetricItem('Sector', displayOrFallback(overview?.sector)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.45,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: context.semanticColors.surfaceMuted,
                    border: Border.all(color: context.semanticColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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
