import 'package:flutter/material.dart';

import '../../../common/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/network/alpha_vantage_client.dart';
import '../news/news_sentiment_screen.dart';
import 'components/components.dart';

class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({super.key, required this.symbol});

  final String symbol;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  static const _refreshThrottle = Duration(seconds: 8);
  static const _chartWindowDays = 30;

  AlphaVantageClient? _client;
  CompanyOverview? _overview;
  List<DailyPricePoint> _priceSeries = const [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastUpdated;
  DateTime? _lastRefreshAt;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();

    try {
      _client = AlphaVantageClient.fromEnv();
      _fetchData();
    } catch (error) {
      _isLoading = false;
      _errorMessage = 'Gagal inisialisasi data source: $error';
    }
  }

  @override
  void dispose() {
    _client?.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool fromPullToRefresh = false}) async {
    if (_client == null) return;

    if (fromPullToRefresh && !_canRefreshNow()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terlalu cepat refresh. Coba lagi beberapa detik.'),
          ),
        );
      }
      return;
    }

    final currentToken = ++_requestToken;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final responses = await Future.wait<dynamic>([
        _client!.fetchCompanyOverview(widget.symbol),
        _client!.fetchDailyTimeSeries(widget.symbol),
      ]);

      if (!mounted || currentToken != _requestToken) return;

      setState(() {
        _overview = responses[0] as CompanyOverview;
        _priceSeries = responses[1] as List<DailyPricePoint>;
        _lastUpdated = DateTime.now();
      });
    } on AlphaVantageApiException catch (error) {
      if (!mounted || currentToken != _requestToken) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || currentToken != _requestToken) return;
      setState(() {
        _errorMessage = 'Gagal memuat detail saham.';
      });
    } finally {
      if (mounted && currentToken == _requestToken) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _canRefreshNow() {
    final now = DateTime.now();
    if (_lastRefreshAt == null ||
        now.difference(_lastRefreshAt!) >= _refreshThrottle) {
      _lastRefreshAt = now;
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final latestPoint = _priceSeries.isNotEmpty ? _priceSeries.last : null;
    final previousPoint = _priceSeries.length > 1
        ? _priceSeries[_priceSeries.length - 2]
        : null;

    final lastClose = latestPoint?.close ?? 0;
    final previousClose = previousPoint?.close ?? 0;
    final delta = lastClose - previousClose;
    final deltaPct = previousClose == 0 ? 0.0 : (delta / previousClose) * 100;
    final moveColor = delta >= 0 ? semantic.success : semantic.danger;

    final chartPoints = _priceSeries.length <= _chartWindowDays
        ? _priceSeries
        : _priceSeries.sublist(_priceSeries.length - _chartWindowDays);

    return Scaffold(
      appBar: AppBar(title: Text(widget.symbol.toUpperCase())),
      body: RefreshIndicator(
        onRefresh: () => _fetchData(fromPullToRefresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading && _overview == null) ...[
              const SizedBox(height: 120),
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              StockDetailHeaderCard(overview: _overview, symbol: widget.symbol),
              const SizedBox(height: 12),
              StockDetailPriceSummaryCard(
                price: lastClose,
                currency: _overview?.currency,
                changeValue: delta,
                changePercent: deltaPct,
                changeColor: moveColor,
                lastUpdated: _lastUpdated,
              ),
              const SizedBox(height: 12),
              StockDetailChartCard(points: chartPoints),
              const SizedBox(height: 12),
              StockDetailFundamentalCard(overview: _overview),
              const SizedBox(height: 12),
              StockDetailDescriptionCard(
                description: _overview?.description ?? '',
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              StockDetailErrorBanner(
                message: _errorMessage!,
                onRetry: _fetchData,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
