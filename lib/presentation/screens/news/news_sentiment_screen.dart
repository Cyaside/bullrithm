import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../common/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/network/alpha_vantage_client.dart';

enum NewsFilterMode { ticker, market }

class NewsSentimentScreen extends StatefulWidget {
  const NewsSentimentScreen({
    super.key,
    this.initialTicker,
    this.showScaffold = true,
  });

  final String? initialTicker;
  final bool showScaffold;

  @override
  State<NewsSentimentScreen> createState() => _NewsSentimentScreenState();
}

class _NewsSentimentScreenState extends State<NewsSentimentScreen> {
  final _tickerController = TextEditingController();
  AlphaVantageClient? _client;

  NewsFilterMode _mode = NewsFilterMode.market;
  List<NewsItem> _items = const [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastUpdated;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialTicker?.trim().toUpperCase() ?? '';
    _tickerController.text = initial;
    _mode = initial.isEmpty ? NewsFilterMode.market : NewsFilterMode.ticker;

    try {
      _client = AlphaVantageClient.fromEnv();
      _fetchNews();
    } catch (error) {
      _isLoading = false;
      _errorMessage = 'Gagal inisialisasi data source: $error';
    }
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _client?.dispose();
    super.dispose();
  }

  Future<void> _fetchNews() async {
    if (_client == null) return;

    final ticker = _tickerController.text.trim().toUpperCase();
    if (_mode == NewsFilterMode.ticker && ticker.isEmpty) {
      setState(() {
        _errorMessage = 'Ticker wajib diisi jika filter menggunakan ticker.';
        _isLoading = false;
      });
      return;
    }

    final currentToken = ++_requestToken;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _client!.fetchNewsSentiment(
        ticker: _mode == NewsFilterMode.ticker ? ticker : null,
        limit: 20,
      );
      if (!mounted || currentToken != _requestToken) return;

      setState(() {
        _items = items;
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
        _errorMessage = 'Gagal memuat berita dan sentimen.';
      });
    } finally {
      if (mounted && currentToken == _requestToken) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openArticle(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL berita tidak valid.')),
        );
      }
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka link berita.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _tickerController.text.trim();

    final content = RefreshIndicator(
      onRefresh: _fetchNews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _TopHeader(
            title: 'Latest News',
            subtitle: 'Market insights & updates',
          ),
          const SizedBox(height: 12),
          Text('Filter Berita', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          SegmentedButton<NewsFilterMode>(
            segments: const [
              ButtonSegment<NewsFilterMode>(
                value: NewsFilterMode.ticker,
                label: Text('By Ticker'),
                icon: Icon(Icons.sell_outlined),
              ),
              ButtonSegment<NewsFilterMode>(
                value: NewsFilterMode.market,
                label: Text('Market'),
                icon: Icon(Icons.public),
              ),
            ],
            selected: <NewsFilterMode>{_mode},
            onSelectionChanged: (selection) {
              setState(() {
                _mode = selection.first;
              });
              _fetchNews();
            },
          ),
          if (_mode == NewsFilterMode.ticker) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _tickerController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Contoh: AAPL',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _fetchNews(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _fetchNews,
                icon: const Icon(Icons.refresh),
                label: const Text('Apply Filter'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _lastUpdated == null
                      ? 'Last updated: -'
                      : 'Last updated: ${_formatDateTime(_lastUpdated!)}',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          if (_mode == NewsFilterMode.ticker && query.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Ticker aktif: $query', style: theme.textTheme.bodySmall),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _NewsErrorBanner(message: _errorMessage!, onRetry: _fetchNews),
          ],
          const SizedBox(height: 16),
          if (_isLoading && _items.isEmpty) ...[
            const Center(child: CircularProgressIndicator()),
          ] else if (_items.isEmpty) ...[
            const _NewsEmptyState(),
          ] else ...[
            ..._items.map(
              (item) =>
                  _NewsCard(item: item, onTap: () => _openArticle(item.url)),
            ),
          ],
        ],
      ),
    );

    if (!widget.showScaffold) {
      return SafeArea(child: content);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('News & Sentiment')),
      body: content,
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.onTap});

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentiment = _sentimentTheme(context, item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.isEmpty ? 'Tanpa Judul' : item.title,
                  style: theme.textTheme.titleLarge,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.source.isEmpty ? 'Unknown source' : item.source} | '
                  '${_formatDateTime(item.timePublished)}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sentiment.background,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    sentiment.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sentiment.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.summary.isEmpty
                      ? 'Ringkasan tidak tersedia.'
                      : item.summary,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsErrorBanner extends StatelessWidget {
  const _NewsErrorBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: semantic.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: semantic.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => onRetry(), child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _NewsEmptyState extends StatelessWidget {
  const _NewsEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.newspaper, color: semantic.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Belum ada berita untuk filter ini.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentimentTheme {
  const _SentimentTheme({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}

_SentimentTheme _sentimentTheme(BuildContext context, NewsItem item) {
  final semantic = context.semanticColors;
  final score = item.overallSentimentScore ?? 0;
  final label = item.overallSentimentLabel.trim().isEmpty
      ? (score > 0.15
            ? 'Bullish'
            : score < -0.15
            ? 'Bearish'
            : 'Neutral')
      : item.overallSentimentLabel;

  if (score > 0.15) {
    return _SentimentTheme(
      label: '$label (${score.toStringAsFixed(2)})',
      foreground: semantic.success,
      background: semantic.success.withValues(alpha: 0.14),
    );
  }
  if (score < -0.15) {
    return _SentimentTheme(
      label: '$label (${score.toStringAsFixed(2)})',
      foreground: semantic.danger,
      background: semantic.danger.withValues(alpha: 0.14),
    );
  }
  return _SentimentTheme(
    label: '$label (${score.toStringAsFixed(2)})',
    foreground: semantic.warning,
    background: semantic.warning.withValues(alpha: 0.14),
  );
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '-';
  final local = dateTime.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
