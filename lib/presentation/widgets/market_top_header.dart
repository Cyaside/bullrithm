import 'package:flutter/material.dart';

import '../../common/theme/theme_mode_controller.dart';

class MarketTopHeader extends StatelessWidget {
  const MarketTopHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeController = ThemeModeScope.of(context);
    final icon = themeController.isDarkMode
        ? Icons.light_mode_rounded
        : Icons.dark_mode_rounded;
    final tooltip = themeController.isDarkMode
        ? 'Switch to light mode'
        : 'Switch to dark mode';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
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
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: themeController.toggle,
            tooltip: tooltip,
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.onPrimary.withValues(
                alpha: 0.14,
              ),
              minimumSize: const Size(34, 34),
              maximumSize: const Size(34, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
            ),
            iconSize: 18,
            icon: Icon(icon, color: theme.colorScheme.onPrimary),
          ),
        ],
      ),
    );
  }
}
