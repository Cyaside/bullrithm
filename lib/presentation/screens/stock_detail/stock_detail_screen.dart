import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../common/theme/app_theme.dart';
import '../../../common/theme/theme_mode_controller.dart';
import '../../controllers/stock_detail_controller.dart';
import '../news/news_sentiment_screen.dart';
import 'components/components.dart';

class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({super.key, required this.symbol});

  final String symbol;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  static const _chartWindowDays = 30;

  StockDetailController? _controller;
  String? _initError;

  @override
  void initState() {
    super.initState();

    try {
      _controller = StockDetailController.fromEnv(symbol: widget.symbol);
      _controller!.initialize();
    } catch (error) {
      _initError = 'Gagal inisialisasi data source: $error';
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return _buildInitError(context, _initError ?? 'Data source belum siap.');
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final semantic = context.semanticColors;
        final themeController = ThemeModeScope.of(context);
        final priceSeries = controller.priceSeries;
        final latestPoint = priceSeries.isNotEmpty ? priceSeries.last : null;
        final previousPoint = priceSeries.length > 1
            ? priceSeries[priceSeries.length - 2]
            : null;

        final lastClose = latestPoint?.close ?? 0;
        final previousClose = previousPoint?.close ?? 0;
        final delta = lastClose - previousClose;
        final deltaPct = previousClose == 0
            ? 0.0
            : (delta / previousClose) * 100;
        final moveColor = delta >= 0 ? semantic.success : semantic.danger;

        final chartPoints = priceSeries.length <= _chartWindowDays
            ? priceSeries
            : priceSeries.sublist(priceSeries.length - _chartWindowDays);

        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text(''),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                onPressed: themeController.toggle,
                tooltip: themeController.isDarkMode
                    ? 'Switch to light mode'
                    : 'Switch to dark mode',
                icon: Icon(
                  themeController.isDarkMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              final result = await controller.refreshFromPullToRefresh();
              if (result == StockDetailRefreshResult.throttled) {
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Terlalu cepat refresh. Coba lagi beberapa detik.',
                    ),
                  ),
                );
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (controller.isLoading && controller.overview == null) ...[
                  const SizedBox(height: 120),
                  const Center(child: CircularProgressIndicator()),
                ] else ...[
                  StockDetailHeaderCard(
                    overview: controller.overview,
                    symbol: widget.symbol,
                    price: lastClose,
                    currency: controller.overview?.currency,
                    changeValue: delta,
                    changePercent: deltaPct,
                    changeColor: moveColor,
                  ),
                  const SizedBox(height: 12),
                  StockDetailChartCard(points: chartPoints),
                  const SizedBox(height: 12),
                  StockDetailFundamentalCard(overview: controller.overview),
                  const SizedBox(height: 12),
                  StockDetailDescriptionCard(
                    description: controller.overview?.description ?? '',
                    websiteUrl: controller.overview?.officialSite,
                    onVisitWebsite: _openOfficialSite,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NewsSentimentScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.newspaper_outlined),
                    label: const Text('News & Sentiment'),
                  ),
                ],
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  StockDetailErrorBanner(
                    message: controller.errorMessage!,
                    onRetry: controller.fetchData,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitError(BuildContext context, String message) {
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          StockDetailErrorBanner(
            message: message,
            onRetry: () async {
              if (_controller != null) {
                await _controller!.fetchData();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openOfficialSite() async {
    final raw = _controller?.overview?.officialSite.trim() ?? '';
    if (raw.isEmpty) return;

    final hasScheme = raw.startsWith('http://') || raw.startsWith('https://');
    final uri = Uri.tryParse(hasScheme ? raw : 'https://$raw');
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka website perusahaan.')),
      );
    }
  }
}
