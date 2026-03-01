import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../common/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/network/alpha_vantage_client.dart';
import '../../widgets/market_top_header.dart';

class NewsSentimentScreen extends StatefulWidget {
  const NewsSentimentScreen({super.key, this.showScaffold = true});

  final bool showScaffold;

  @override
  State<NewsSentimentScreen> createState() => _NewsSentimentScreenState();
}

class _NewsSentimentScreenState extends State<NewsSentimentScreen> {
  AlphaVantageClient? _client;

  List<NewsItem> _items = const [];
  NewsSentimentFilter _filter = NewsSentimentFilter.all;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastUpdated;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();

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
    _client?.dispose();
    super.dispose();
  }

  Future<void> _fetchNews() async {
    if (_client == null) return;

    final currentToken = ++_requestToken;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _client!.fetchNewsSentiment(limit: 1000);
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

  List<NewsItem> get _filteredItems {
    if (_filter == NewsSentimentFilter.all) return _items;
    return _items
        .where((item) => _matchesFilter(_classifySentiment(item), _filter))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    final content = RefreshIndicator(
      onRefresh: _fetchNews,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          const MarketTopHeader(
            title: 'Latest News',
            subtitle: 'Market insights & updates',
          ),
          const SizedBox(height: 12),
          _NewsToolbar(
            lastUpdated: _lastUpdated,
            isLoading: _isLoading,
            selectedFilter: _filter,
            onFilterChanged: (filter) {
              setState(() {
                _filter = filter;
              });
            },
            onRefresh: _fetchNews,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _NewsErrorBanner(message: _errorMessage!, onRetry: _fetchNews),
          ],
          const SizedBox(height: 12),
          if (_isLoading && _items.isEmpty) ...[
            const _NewsLoadingList(),
          ] else if (filteredItems.isEmpty) ...[
            _NewsEmptyState(filter: _filter),
          ] else ...[
            ...filteredItems.map(
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

class _NewsToolbar extends StatelessWidget {
  const _NewsToolbar({
    required this.lastUpdated,
    required this.isLoading,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onRefresh,
  });

  final DateTime? lastUpdated;
  final bool isLoading;
  final NewsSentimentFilter selectedFilter;
  final ValueChanged<NewsSentimentFilter> onFilterChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: NewsSentimentFilter.values
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter.label),
                      selected: selectedFilter == filter,
                      onSelected: (_) => onFilterChanged(filter),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: isLoading ? null : () => onRefresh(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh News'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                lastUpdated == null
                    ? 'Last updated: -'
                    : 'Last updated: ${_formatDateTime(lastUpdated!)}',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum NewsSentimentFilter {
  all('All'),
  bullish('Bullish'),
  somewhatBullish('Somewhat Bullish'),
  neutral('Neutral'),
  somewhatBearish('Somewhat Bearish'),
  bearish('Bearish');

  const NewsSentimentFilter(this.label);
  final String label;
}

enum SentimentBucket {
  bullish('BULLISH'),
  somewhatBullish('SOMEWHAT BULLISH'),
  neutral('NEUTRAL'),
  somewhatBearish('SOMEWHAT BEARISH'),
  bearish('BEARISH');

  const SentimentBucket(this.label);
  final String label;
}

bool _matchesFilter(SentimentBucket bucket, NewsSentimentFilter filter) {
  switch (filter) {
    case NewsSentimentFilter.all:
      return true;
    case NewsSentimentFilter.bullish:
      return bucket == SentimentBucket.bullish;
    case NewsSentimentFilter.somewhatBullish:
      return bucket == SentimentBucket.somewhatBullish;
    case NewsSentimentFilter.neutral:
      return bucket == SentimentBucket.neutral;
    case NewsSentimentFilter.somewhatBearish:
      return bucket == SentimentBucket.somewhatBearish;
    case NewsSentimentFilter.bearish:
      return bucket == SentimentBucket.bearish;
  }
}

SentimentBucket _classifySentiment(NewsItem item) {
  final rawLabel = item.overallSentimentLabel.trim().toUpperCase();
  final normalized = rawLabel
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized.contains('SOMEWHAT BULLISH')) {
    return SentimentBucket.somewhatBullish;
  }
  if (normalized == 'BULLISH') return SentimentBucket.bullish;
  if (normalized.contains('SOMEWHAT BEARISH')) {
    return SentimentBucket.somewhatBearish;
  }
  if (normalized == 'BEARISH') return SentimentBucket.bearish;
  if (normalized == 'NEUTRAL') return SentimentBucket.neutral;

  final score = item.overallSentimentScore ?? 0;
  if (score >= 0.35) return SentimentBucket.bullish;
  if (score > 0.05) return SentimentBucket.somewhatBullish;
  if (score <= -0.35) return SentimentBucket.bearish;
  if (score < -0.05) return SentimentBucket.somewhatBearish;
  return SentimentBucket.neutral;
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
  final bucket = _classifySentiment(item);
  final score = item.overallSentimentScore ?? 0;
  final label = '${bucket.label} (${score.toStringAsFixed(2)})';

  switch (bucket) {
    case SentimentBucket.bullish:
      return _SentimentTheme(
        label: label,
        foreground: semantic.success,
        background: semantic.success.withValues(alpha: 0.2),
      );
    case SentimentBucket.somewhatBullish:
      return _SentimentTheme(
        label: label,
        foreground: semantic.success.withValues(alpha: 0.85),
        background: semantic.success.withValues(alpha: 0.1),
      );
    case SentimentBucket.bearish:
      return _SentimentTheme(
        label: label,
        foreground: semantic.danger,
        background: semantic.danger.withValues(alpha: 0.2),
      );
    case SentimentBucket.somewhatBearish:
      return _SentimentTheme(
        label: label,
        foreground: semantic.danger.withValues(alpha: 0.85),
        background: semantic.danger.withValues(alpha: 0.1),
      );
    case SentimentBucket.neutral:
      return _SentimentTheme(
        label: label,
        foreground: semantic.warning,
        background: semantic.warning.withValues(alpha: 0.14),
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
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: sentiment.background,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        sentiment.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: sentiment.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.source.isEmpty ? 'Unknown source' : item.source} | '
                        '${_formatDateTime(item.timePublished)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.title.isEmpty ? 'Tanpa Judul' : item.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item.summary.isEmpty
                      ? 'Ringkasan tidak tersedia.'
                      : item.summary,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                _NewsPreviewImage(imageUrl: item.bannerImageUrl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsPreviewImage extends StatelessWidget {
  const _NewsPreviewImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imageUrl.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 115,
        width: double.infinity,
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _NewsPreviewFallback(theme: theme),
              )
            : _NewsPreviewFallback(theme: theme),
      ),
    );
  }
}

class _NewsPreviewFallback extends StatelessWidget {
  const _NewsPreviewFallback({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.16),
            theme.colorScheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.newspaper_rounded,
          size: 32,
          color: theme.colorScheme.primary.withValues(alpha: 0.7),
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
          FilledButton.tonal(
            onPressed: () => onRetry(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _NewsEmptyState extends StatelessWidget {
  const _NewsEmptyState({required this.filter});

  final NewsSentimentFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.newspaper_rounded, color: semantic.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                filter == NewsSentimentFilter.all
                    ? 'Belum ada berita untuk filter ini.'
                    : 'Belum ada berita untuk sentimen ${filter.label}.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsLoadingList extends StatelessWidget {
  const _NewsLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: SizedBox(
            height: 188,
            child: Card(
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
