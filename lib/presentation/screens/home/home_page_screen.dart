import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../common/theme/app_theme.dart';
import '../../widgets/market_top_header.dart';

class HomePageScreen extends StatelessWidget {
  const HomePageScreen({
    super.key,
    this.showScaffold = true,
    this.onNavigateToTab,
  });

  final bool showScaffold;
  final ValueChanged<int>? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        const MarketTopHeader(
          title: 'Home',
          subtitle: 'Your quick launch pad for Bullrithm.',
          leading: Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 12),
        const _HeroBanner(),
        const SizedBox(height: 12),
        const _DailyMotivationCard(),
        const SizedBox(height: 14),
        const _HomeSectionTitle(
          title: 'Explore',
          subtitle: 'Quickly jump into the right section.',
        ),
        const SizedBox(height: 10),
        _FeatureGrid(onNavigateToTab: onNavigateToTab),
        const SizedBox(height: 14),
        const _WorkflowCard(),
      ],
    );

    if (!showScaffold) {
      return SafeArea(child: body);
    }

    return Scaffold(body: SafeArea(child: body));
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.asset('assets/banner.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.58),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bullrithm Home',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Move with structure. Read sentiment. Stay intentional.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  const _HomeSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.18,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        _FeatureCard(
          icon: Icons.candlestick_chart,
          title: 'Stocks',
          subtitle: 'Watch movers and find symbols fast.',
          accent: theme.colorScheme.primary,
          onTap: () => onNavigateToTab?.call(1),
        ),
        _FeatureCard(
          icon: Icons.newspaper_rounded,
          title: 'News',
          subtitle: 'Read sentiment with local filtering.',
          accent: theme.colorScheme.secondary,
          onTap: () => onNavigateToTab?.call(2),
        ),
        _FeatureCard(
          icon: Icons.person,
          title: 'Profile',
          subtitle: 'Customize details and photo locally.',
          accent: theme.colorScheme.tertiary,
          onTap: () => onNavigateToTab?.call(3),
        ),
        _FeatureCard(
          icon: Icons.auto_graph_rounded,
          title: 'Market Movers',
          subtitle: 'Jump to top gainers and losers.',
          accent: theme.colorScheme.primary.withValues(alpha: 0.9),
          onTap: () => onNavigateToTab?.call(1),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: semantic.surfaceMuted,
            border: Border.all(color: semantic.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: accent),
                ),
                const Spacer(),
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Workflow',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const _WorkflowRow(
              step: '1',
              title: 'Scan Movers',
              subtitle:
                  'Open Stocks tab for gainers, losers, and active names.',
            ),
            const SizedBox(height: 8),
            const _WorkflowRow(
              step: '2',
              title: 'Check Sentiment',
              subtitle: 'Open News tab and filter signal strength locally.',
            ),
            const SizedBox(height: 8),
            const _WorkflowRow(
              step: '3',
              title: 'Review Profile Setup',
              subtitle: 'Keep your personal dashboard and links up to date.',
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowRow extends StatelessWidget {
  const _WorkflowRow({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary.withValues(alpha: 0.14),
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyMotivationCard extends StatefulWidget {
  const _DailyMotivationCard();

  @override
  State<_DailyMotivationCard> createState() => _DailyMotivationCardState();
}

class _DailyMotivationCardState extends State<_DailyMotivationCard> {
  static const _cacheDateKey = 'daily_motivation_date_v1';
  static const _cacheContentKey = 'daily_motivation_content_v1';
  static const _cacheAuthorKey = 'daily_motivation_author_v1';

  late final Future<_MotivationQuote?> _quoteFuture = _loadQuote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<_MotivationQuote?>(
      future: _quoteFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final quote = snapshot.data;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isLoading)
                  Text(
                    'Loading quote...',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  )
                else if (quote == null)
                  Text(
                    'Daily quote unavailable right now.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  )
                else ...[
                  Text(
                    '"${quote.content}"',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '~ ${quote.author}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_MotivationQuote?> _loadQuote() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _formatDate(DateTime.now());

    final cachedDate = prefs.getString(_cacheDateKey)?.trim() ?? '';
    final cachedContent = prefs.getString(_cacheContentKey)?.trim() ?? '';
    final cachedAuthor = prefs.getString(_cacheAuthorKey)?.trim() ?? '';

    if (cachedDate == today && cachedContent.isNotEmpty) {
      return _MotivationQuote(
        content: cachedContent,
        author: cachedAuthor.isEmpty ? 'Unknown' : cachedAuthor,
      );
    }

    try {
      final uri = Uri.parse('https://zenquotes.io/api/random');
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
          final first = (decoded.first as Map).map(
            (key, value) => MapEntry('$key', value),
          );
          final content = (first['q'] as String?)?.trim() ?? '';
          final author = (first['a'] as String?)?.trim() ?? 'Unknown';
          if (content.isNotEmpty) {
            await prefs.setString(_cacheDateKey, today);
            await prefs.setString(_cacheContentKey, content);
            await prefs.setString(_cacheAuthorKey, author);
            return _MotivationQuote(content: content, author: author);
          }
        }
      }
    } catch (_) {
      // Error handled by returning null/cache.
    }

    if (cachedContent.isNotEmpty) {
      return _MotivationQuote(
        content: cachedContent,
        author: cachedAuthor.isEmpty ? 'Unknown' : cachedAuthor,
      );
    }
    return null;
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _MotivationQuote {
  const _MotivationQuote({required this.content, required this.author});

  final String content;
  final String author;
}
