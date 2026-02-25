class SearchResultItem {
  const SearchResultItem({
    required this.symbol,
    required this.name,
    required this.region,
    required this.currency,
    required this.type,
    required this.matchScore,
  });

  final String symbol;
  final String name;
  final String region;
  final String currency;
  final String type;
  final double? matchScore;

  factory SearchResultItem.fromAlphaVantage(Map<String, dynamic> json) {
    return SearchResultItem(
      symbol: _readString(json, '1. symbol'),
      name: _readString(json, '2. name'),
      type: _readString(json, '3. type'),
      region: _readString(json, '4. region'),
      currency: _readString(json, '8. currency'),
      matchScore: _readDouble(json, '9. matchScore'),
    );
  }
}

String _readString(Map<String, dynamic> json, String key) {
  return (json[key] as String?)?.trim() ?? '';
}

double? _readDouble(Map<String, dynamic> json, String key) {
  final raw = json[key];
  if (raw == null) return null;
  return double.tryParse(raw.toString());
}
