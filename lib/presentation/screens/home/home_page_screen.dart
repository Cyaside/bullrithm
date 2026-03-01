import 'package:flutter/material.dart';

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
        SizedBox(height: 14),
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
