class CompanyOverview {
  const CompanyOverview({
    required this.symbol,
    required this.name,
    required this.description,
    required this.officialSite,
    required this.sector,
    required this.industry,
    required this.marketCapitalization,
    required this.peRatio,
    required this.dividendYield,
    required this.currency,
    required this.country,
    required this.exchange,
  });

  final String symbol;
  final String name;
  final String description;
  final String officialSite;
  final String sector;
  final String industry;
  final int? marketCapitalization;
  final double? peRatio;
  final double? dividendYield;
  final String currency;
  final String country;
  final String exchange;

  factory CompanyOverview.fromAlphaVantage(Map<String, dynamic> json) {
    return CompanyOverview(
      symbol: _s(json, 'Symbol'),
      name: _s(json, 'Name'),
      description: _s(json, 'Description'),
      officialSite: _s(json, 'OfficialSite'),
      sector: _s(json, 'Sector'),
      industry: _s(json, 'Industry'),
      marketCapitalization: _i(json, 'MarketCapitalization'),
      peRatio: _d(json, 'PERatio'),
      dividendYield: _d(json, 'DividendYield'),
      currency: _s(json, 'Currency'),
      country: _s(json, 'Country'),
      exchange: _s(json, 'Exchange'),
    );
  }
}

String _s(Map<String, dynamic> json, String key) =>
    (json[key] as String?)?.trim() ?? '';

int? _i(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return int.tryParse(value.toString());
}

double? _d(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return double.tryParse(value.toString());
}
