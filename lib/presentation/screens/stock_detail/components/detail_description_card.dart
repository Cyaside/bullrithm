import 'package:flutter/material.dart';

class StockDetailDescriptionCard extends StatelessWidget {
  const StockDetailDescriptionCard({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = description.trim().isEmpty
        ? 'Data tidak tersedia'
        : description.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deskripsi', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(display, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
