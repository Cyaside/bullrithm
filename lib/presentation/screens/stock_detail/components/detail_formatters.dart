String displayOrFallback(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'Data tidak tersedia' : trimmed;
}

String compactCurrencyCode(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? 'USD' : trimmed.toUpperCase();
}

String formatDecimal(num value) {
  final negative = value < 0;
  final abs = value.abs().toStringAsFixed(2);
  final parts = abs.split('.');
  final intPart = parts.first;
  final decPart = parts.last;

  final sb = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final reversedIndex = intPart.length - i;
    sb.write(intPart[i]);
    if (reversedIndex > 1 && reversedIndex % 3 == 1) {
      sb.write(',');
    }
  }

  final prefix = negative ? '-' : '';
  return '$prefix${sb.toString()}.$decPart';
}

String formatMarketCap(int? value) {
  if (value == null) return 'Data tidak tersedia';
  final v = value.toDouble();

  if (v >= 1e12) return '${(v / 1e12).toStringAsFixed(2)} T';
  if (v >= 1e9) return '${(v / 1e9).toStringAsFixed(2)} B';
  if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(2)} M';
  if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(2)} K';
  return value.toString();
}

String formatDividendYield(double? value) {
  if (value == null) return 'Data tidak tersedia';
  final percent = value * 100;
  return '${percent.toStringAsFixed(2)}%';
}
