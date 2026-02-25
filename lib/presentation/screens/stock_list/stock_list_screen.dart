import 'package:flutter/material.dart';

import '../../../common/config/app_env.dart';
import '../../../common/theme/app_theme.dart';

class StockListScreen extends StatelessWidget {
  const StockListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Stocks')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Cari ticker saham', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Fondasi proyek siap. Search API akan disambungkan pada langkah berikutnya.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            enabled: false,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'AAPL, TSLA, MSFT...',
            ),
          ),
          const SizedBox(height: 16),
          _StatusCard(
            title: 'API Key',
            value: AppEnv.hasAlphaVantageApiKey ? 'Terdeteksi' : 'Belum diisi',
            valueColor: AppEnv.hasAlphaVantageApiKey
                ? semantic.success
                : semantic.warning,
            subtitle: 'Isi ALPHA_VANTAGE_API_KEY di .env',
          ),
          const SizedBox(height: 12),
          _StatusCard(
            title: 'Theme',
            value: 'Light/Dark siap',
            valueColor: theme.colorScheme.primary,
            subtitle: 'Token warna mengikuti PRD',
          ),
          const SizedBox(height: 12),
          _StatusCard(
            title: 'Networking',
            value: 'AlphaVantageClient siap',
            valueColor: theme.colorScheme.primary,
            subtitle: 'Base URL, timeout, logging, error handling',
          ),
          const SizedBox(height: 12),
          _StatusCard(
            title: 'Models',
            value: '4 model dasar siap',
            valueColor: theme.colorScheme.primary,
            subtitle: 'Search, overview, daily price, news',
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.subtitle,
  });

  final String title;
  final String value;
  final Color valueColor;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 48,
              decoration: BoxDecoration(
                color: valueColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: valueColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: semantic.border),
          ],
        ),
      ),
    );
  }
}
