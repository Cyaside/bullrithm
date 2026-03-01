import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/network/alpha_vantage_client.dart';
import '../../widgets/market_top_header.dart';
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
    final query = _searchController.text.trim();

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const MarketTopHeader(
          title: 'Market Overview',
          subtitle: "Today's top performers",
        ),
        const SizedBox(height: 12),
        _SearchField(
          controller: _searchController,
          query: query,
          onChanged: _onQueryChanged,
          onClear: () {
            _searchController.clear();
            _onQueryChanged('');
            setState(() {});
          },
        ),
        const SizedBox(height: 12),
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
          showSelectedIcon: false,
          selected: <MarketMoverTab>{_selectedMoverTab},
          onSelectionChanged: (value) {
            setState(() {
              _selectedMoverTab = value.first;
            });
          },
        ),
        if (query.isEmpty && _moversErrorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _moversErrorMessage!),
        ],
        if (query.isNotEmpty && _errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _errorMessage!),
        ],
        const SizedBox(height: 12),
        if (query.isEmpty) ...[
          if (_isMoversLoading)
            const _LoadingList(itemHeight: 65, items: 7)
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
          if (_isLoading)
            const _LoadingList(itemHeight: 65, items: 4)
          else if (_results.isNotEmpty)
            _ResultList(results: _results)
          else
            const _EmptyState(),
        ],
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Cari ticker (AAPL, TSLA, MSFT...)',
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear',
              ),
      ),
    );
  }
}

class _MarketMoverList extends StatelessWidget {
  const _MarketMoverList({required this.items});

  final List<MarketMoverItem> items;

  @override
  Widget build(BuildContext context) {
    final dividerColor = context.semanticColors.border;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: items
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _MarketMoverRow(item: item),
                  if (index != items.length - 1)
                    Divider(height: 1, color: dividerColor),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _MarketMoverRow extends StatelessWidget {
  const _MarketMoverRow({required this.item});

  final MarketMoverItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final isUp = item.changePercent >= 0;
    final moveColor = isUp ? semantic.success : semantic.danger;
    final deltaPrefix = isUp ? '+' : '';
    final icon = isUp ? Icons.north_east_rounded : Icons.south_east_rounded;

    return InkWell(
      onTap: item.symbol.trim().isEmpty
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StockDetailScreen(symbol: item.symbol),
                ),
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.symbol.toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Vol ${item.volume}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${item.price.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 13, color: moveColor),
                    const SizedBox(width: 2),
                    Text(
                      '$deltaPrefix${item.changePercent.toStringAsFixed(2)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: moveColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
    final dividerColor = context.semanticColors.border;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: results
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _ResultRow(item: item),
                  if (index != results.length - 1)
                    Divider(height: 1, color: dividerColor),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (item.name.isNotEmpty) item.name,
      if (item.region.isNotEmpty) item.region,
      if (item.currency.isNotEmpty) item.currency,
    ];

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => StockDetailScreen(symbol: item.symbol),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.symbol.isEmpty ? '-' : item.symbol,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.isEmpty
                        ? 'Data tidak tersedia'
                        : subtitleParts.join(' | '),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList({required this.itemHeight, required this.items});

  final double itemHeight;
  final int items;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: List.generate(items, (index) {
          return SizedBox(
            height: itemHeight,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }),
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded, color: semantic.warning),
            const SizedBox(width: 10),
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
        border: Border.all(color: semantic.danger.withValues(alpha: 0.36)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: semantic.danger),
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
