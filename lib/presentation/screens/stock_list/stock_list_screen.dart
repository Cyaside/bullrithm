import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/network/alpha_vantage_client.dart';
import '../stock_detail/stock_detail_screen.dart';

enum MarketMoverTab { gainers, losers, active }

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key, this.showScaffold = true});

  final bool showScaffold;

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

  MarketMoverTab _selectedMoverTab = MarketMoverTab.gainers;
  bool _isMoversLoading = false;
  String? _moversErrorMessage;
  List<MarketMoverItem> _gainers = const [];
  List<MarketMoverItem> _losers = const [];
  List<MarketMoverItem> _active = const [];

  @override
  void initState() {
    super.initState();

    try {
      _client = AlphaVantageClient.fromEnv();
      _fetchMovers();
    } catch (error) {
      _errorMessage = 'Gagal inisialisasi data source: $error';
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

  Future<void> _fetchMovers() async {
    if (_client == null) return;

    setState(() {
      _isMoversLoading = true;
      _moversErrorMessage = null;
    });

    try {
      final raw = await _client!.fetchTopGainersLosers();
      if (!mounted) return;

      setState(() {
        _gainers = _parseMovers(raw['top_gainers']);
        _losers = _parseMovers(raw['top_losers']);
        _active = _parseMovers(raw['most_actively_traded']);
      });
    } on AlphaVantageApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _moversErrorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _moversErrorMessage = 'Gagal memuat market movers.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMoversLoading = false;
        });
      }
    }
  }

  List<MarketMoverItem> _parseMovers(dynamic rawList) {
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map>()
        .map(
          (item) => MarketMoverItem(
            symbol: (item['ticker'] ?? item['symbol'] ?? '').toString(),
            price: _toDouble(item['price']),
            changePercent: _parsePercent(item['change_percentage']),
            volume: (item['volume'] ?? '-').toString(),
          ),
        )
        .where((e) => e.symbol.trim().isNotEmpty)
        .toList(growable: false);
  }

  void _rememberQuery(String query) {
    _recentQueries.remove(query);
    _recentQueries.insert(0, query);
    if (_recentQueries.length > _maxRecentQueries) {
      _recentQueries.removeRange(_maxRecentQueries, _recentQueries.length);
    }
  }

  List<MarketMoverItem> get _selectedMovers {
    switch (_selectedMoverTab) {
      case MarketMoverTab.gainers:
        return _gainers;
      case MarketMoverTab.losers:
        return _losers;
      case MarketMoverTab.active:
        return _active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim();

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _TopHeader(
          title: 'Market Overview',
          subtitle: "Today's top performers",
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Cari ticker (AAPL, TSLA, MSFT...)',
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
        const SizedBox(height: 12),
        if (query.isEmpty) ...[
          SegmentedButton<MarketMoverTab>(
            segments: const [
              ButtonSegment<MarketMoverTab>(
                value: MarketMoverTab.gainers,
                label: Text('Gainers'),
              ),
              ButtonSegment<MarketMoverTab>(
                value: MarketMoverTab.losers,
                label: Text('Losers'),
              ),
              ButtonSegment<MarketMoverTab>(
                value: MarketMoverTab.active,
                label: Text('Active'),
              ),
            ],
            selected: <MarketMoverTab>{_selectedMoverTab},
            onSelectionChanged: (value) {
              setState(() {
                _selectedMoverTab = value.first;
              });
            },
          ),
          const SizedBox(height: 12),
          if (_moversErrorMessage != null) ...[
            _ErrorBanner(message: _moversErrorMessage!),
            const SizedBox(height: 12),
          ],
          if (_isMoversLoading)
            const _LoadingList()
          else if (_selectedMovers.isNotEmpty)
            _MarketMoverList(items: _selectedMovers)
          else
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
        ] else ...[
          if (_isLoading) ...[
            const _LoadingList(),
          ] else if (_results.isEmpty) ...[
            const _EmptyState(),
          ] else ...[
            _ResultList(results: _results),
          ],
        ],
        const SizedBox(height: 8),
        Text(
          'Tap item untuk buka detail.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );

    if (!widget.showScaffold) {
      return SafeArea(child: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Stocks')),
      body: body,
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

class _MarketMoverList extends StatelessWidget {
  const _MarketMoverList({required this.items});

  final List<MarketMoverItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map((item) => _MarketMoverCard(item: item))
          .toList(growable: false),
    );
  }
}

class _MarketMoverCard extends StatelessWidget {
  const _MarketMoverCard({required this.item});

  final MarketMoverItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final isUp = item.changePercent >= 0;
    final color = isUp ? semantic.success : semantic.danger;
    final prefix = isUp ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 4,
          ),
          title: Text(item.symbol, style: theme.textTheme.titleLarge),
          subtitle: Text(
            'Vol: ${item.volume}',
            style: theme.textTheme.bodySmall,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${item.price.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '$prefix${item.changePercent.toStringAsFixed(2)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 8),
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
          padding: EdgeInsets.only(bottom: 8),
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

class MarketMoverItem {
  const MarketMoverItem({
    required this.symbol,
    required this.price,
    required this.changePercent,
    required this.volume,
  });

  final String symbol;
  final double price;
  final double changePercent;
  final String volume;
}

double _toDouble(Object? raw) => double.tryParse(raw?.toString() ?? '') ?? 0;

double _parsePercent(Object? raw) {
  final value = (raw?.toString() ?? '').replaceAll('%', '').trim();
  return double.tryParse(value) ?? 0;
}
