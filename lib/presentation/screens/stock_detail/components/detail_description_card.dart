import 'package:flutter/material.dart';

class StockDetailDescriptionCard extends StatelessWidget {
  const StockDetailDescriptionCard({
    super.key,
    required this.description,
    this.websiteUrl,
    this.onVisitWebsite,
  });

  final String description;
  final String? websiteUrl;
  final VoidCallback? onVisitWebsite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = description.trim().isEmpty
        ? 'Data tidak tersedia'
        : description.trim();
    final hasWebsite = (websiteUrl?.trim().isNotEmpty ?? false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(display, style: theme.textTheme.bodyMedium),
            if (hasWebsite) ...[
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onVisitWebsite,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Visit Website',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
