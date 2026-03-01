import 'package:flutter/material.dart';

import '../../../common/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../domain/domain.dart';
import '../../controllers/stock_list_controller.dart';
import '../../widgets/market_top_header.dart';
import '../stock_detail/stock_detail_screen.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key, this.showScaffold = true});

  final bool showScaffold;

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final _searchController = TextEditingController();
  StockListController? _controller;
  String? _initError;

  @override
  void initState() {
    super.initState();

    try {
      _controller = StockListController.fromEnv();
      _controller!.initialize();
    } catch (error) {
      _initError = 'Gagal inisialisasi data source: $error';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return _buildInitError(context, _initError ?? 'Data source belum siap.');
    }

    final content = AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final query = controller.query.trim();

        return ListView(
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
              onChanged: controller.onQueryChanged,
              onClear: () {
                _searchController.clear();
                controller.clearQuery();
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
              selected: <MarketMoverTab>{controller.selectedMoverTab},
              onSelectionChanged: (value) {
                controller.selectMoverTab(value.first);
              },
            ),
            if (query.isEmpty && controller.moversErrorMessage != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: controller.moversErrorMessage!),
            ],
            if (query.isNotEmpty && controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: controller.errorMessage!),
            ],
            const SizedBox(height: 12),
            if (query.isEmpty) ...[
              if (controller.isMoversLoading)
                const _LoadingList(itemHeight: 65, items: 7)
              else if (controller.selectedMovers.isNotEmpty)
                _MarketMoverList(items: controller.selectedMovers)
              else
                _RecentQueries(
                  queries: controller.recentQueries,
                  onTapQuery: (selectedQuery) {
                    _searchController.text = selectedQuery;
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: selectedQuery.length),
                    );
                    controller.onQueryChanged(selectedQuery);
                  },
                ),
            ] else ...[
              if (controller.isLoading)
                const _LoadingList(itemHeight: 65, items: 4)
              else if (controller.results.isNotEmpty)
                _ResultList(results: controller.results)
              else
                const _EmptyState(),
            ],
          ],
        );
      },
    );

    if (!widget.showScaffold) {
      return SafeArea(child: content);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Stocks')),
      body: content,
    );
  }

  Widget _buildInitError(BuildContext context, String message) {
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        const MarketTopHeader(
          title: 'Market Overview',
          subtitle: "Today's top performers",
        ),
        const SizedBox(height: 12),
        _ErrorBanner(message: message),
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
