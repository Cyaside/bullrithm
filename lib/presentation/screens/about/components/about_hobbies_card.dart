import 'package:flutter/material.dart';

import '../../../../common/theme/app_theme.dart';

class AboutHobbiesCard extends StatelessWidget {
  const AboutHobbiesCard({super.key, required this.hobbies});

  final List<String> hobbies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hobi', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            if (hobbies.isEmpty)
              Text('Belum ada hobi.', style: theme.textTheme.bodyMedium)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: hobbies
                    .map(
                      (hobby) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: semantic.surfaceMuted,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: semantic.border),
                        ),
                        child: Text(hobby, style: theme.textTheme.bodySmall),
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
