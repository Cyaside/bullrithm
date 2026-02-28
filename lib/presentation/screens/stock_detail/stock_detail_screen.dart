import 'package:flutter/material.dart';

class StockDetailScreen extends StatelessWidget {
  const StockDetailScreen({super.key, required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(symbol.isEmpty ? 'Detail Saham' : symbol)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Halaman detail untuk $symbol akan diimplementasikan pada Step 3 (OVERVIEW + TIME_SERIES_DAILY).',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
