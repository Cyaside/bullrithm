import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/config/app_env.dart';
import '../../../common/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/network/alpha_vantage_client.dart';
import '../about/about_me_screen.dart';
import '../stock_detail/stock_detail_screen.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  static const _debounceDuration = Duration(milliseconds: 600);
  static const _maxRecentQueries = 10;

  final _searchController = TextEditingController();
  final _queryCache = <String, List<SearchResultItem>>{};
  final _recentQueries = <String>[];

  Timer? _debounce;
  AlphaVantageClient? _client;
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchResultItem> _results = const [];
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();

    if (AppEnv.hasAlphaVantageProxyUrl) {
      _client = AlphaVantageClient.fromEnv();
    } else {
      _errorMessage =
          'Proxy URL belum diisi. Jalankan dengan --dart-define='
          'ALPHA_VANTAGE_PROXY_URL=https://<worker-url>/query';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _client?.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _search(value));
  }

  Future<void> _search(String query) async {
    final normalized = query.trim();

    if (_client == null) {
      setState(() {
        _isLoading = false;
        _results = const [];
      });
      return;
    }

    if (normalized.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _results = const [];
      });
      return;
    }

    final cacheKey = normalized.toLowerCase();
    final cached = _queryCache[cacheKey];

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (cached != null) {
        _results = cached;
      }
    });

    final currentToken = ++_requestToken;

    try {
      final fresh = await _client!.searchSymbols(normalized);
      if (!mounted || currentToken != _requestToken) return;

      _queryCache[cacheKey] = fresh;
      _rememberQuery(normalized);
      setState(() {
        _results = fresh;
      });
    } on AlphaVantageApiException catch (error) {
      if (!mounted || currentToken != _requestToken) return;

      final fallback = _queryCache[cacheKey] ?? const <SearchResultItem>[];
      setState(() {
        _results = fallback;
        if (fallback.isNotEmpty && error.isRateLimit) {
          _errorMessage = 'Rate limit terkena, menampilkan hasil cache.';
        } else {
          _errorMessage = error.message;
        }
      });
    } catch (_) {
      if (!mounted || currentToken != _requestToken) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat memuat data saham.';
      });
    } finally {
      if (mounted && currentToken == _requestToken) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _rememberQuery(String query) {
    _recentQueries.remove(query);
    _recentQueries.insert(0, query);
    if (_recentQueries.length > _maxRecentQueries) {
      _recentQueries.removeRange(_maxRecentQueries, _recentQueries.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stocks'),
        actions: [
          IconButton(
            tooltip: 'About Me',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutMeScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Cari ticker saham', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'SYMBOL_SEARCH dengan debounce 600ms untuk hemat kuota API.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'AAPL, TSLA, MSFT...',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear',
                    ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 16),
          if (_isLoading) ...[
            const _LoadingList(),
          ] else if (query.isEmpty) ...[
            _RecentQueries(
              queries: _recentQueries,
              onTapQuery: (selectedQuery) {
                _searchController.text = selectedQuery;
                _searchController.selection = TextSelection.fromPosition(
                  TextPosition(offset: selectedQuery.length),
                );
                _onQueryChanged(selectedQuery);
                setState(() {});
              },
            ),
          ] else if (_results.isEmpty) ...[
            const _EmptyState(),
          ] else ...[
            _ResultList(results: _results),
          ],
        ],
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.results});

  final List<SearchResultItem> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: results
          .map((item) => _ResultCard(item: item))
          .toList(growable: false),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (item.name.isNotEmpty) item.name,
      if (item.region.isNotEmpty) item.region,
      if (item.currency.isNotEmpty) item.currency,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          title: Text(
            item.symbol.isEmpty ? '-' : item.symbol,
            style: theme.textTheme.titleLarge,
          ),
          subtitle: Text(
            subtitleParts.isEmpty
                ? 'Data tidak tersedia'
                : subtitleParts.join(' | '),
            style: theme.textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StockDetailScreen(symbol: item.symbol),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: SizedBox(
            height: 76,
            child: Card(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.search_off, color: semantic.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ticker tidak ditemukan. Coba kata kunci lain.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Container(
      decoration: BoxDecoration(
        color: semantic.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: semantic.danger.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: semantic.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentQueries extends StatelessWidget {
  const _RecentQueries({required this.queries, required this.onTapQuery});

  final List<String> queries;
  final ValueChanged<String> onTapQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Searches', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            if (queries.isEmpty)
              Text(
                'Belum ada pencarian. Coba ketik ticker seperti AAPL.',
                style: theme.textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: queries
                    .map(
                      (query) => ActionChip(
                        label: Text(query),
                        onPressed: () => onTapQuery(query),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}
