import '../../domain/domain.dart';
import '../models/models.dart';
import '../network/alpha_vantage_client.dart';

class AlphaVantageMarketRepository implements MarketRepository {
  AlphaVantageMarketRepository._(this._client);

  factory AlphaVantageMarketRepository.fromEnv() {
    return AlphaVantageMarketRepository._(AlphaVantageClient.fromEnv());
  }

  final AlphaVantageClient _client;

  @override
  Future<List<SearchResultItem>> searchSymbols(String keywords) {
    return _client.searchSymbols(keywords);
  }

  @override
  Future<MarketMovers> getMarketMovers() async {
    final raw = await _client.fetchTopGainersLosers();
    return MarketMovers(
      gainers: _parseMovers(raw['top_gainers']),
      losers: _parseMovers(raw['top_losers']),
      active: _parseMovers(raw['most_actively_traded']),
    );
  }

  @override
  Future<CompanyOverview> getCompanyOverview(String symbol) {
    return _client.fetchCompanyOverview(symbol);
  }

  @override
  Future<List<DailyPricePoint>> getDailyTimeSeries(String symbol) {
    return _client.fetchDailyTimeSeries(symbol);
  }

  @override
  Future<List<NewsItem>> getNewsSentiment({String? ticker, int limit = 1000}) {
    return _client.fetchNewsSentiment(ticker: ticker, limit: limit);
  }

  @override
  void dispose() {
    _client.dispose();
  }
}

List<MarketMoverItem> _parseMovers(dynamic rawList) {
  if (rawList is! List) return const [];
  return rawList
      .whereType<Map>()
      .map(
        (item) => MarketMoverItem(
          symbol: (item['ticker'] ?? item['symbol'] ?? '').toString(),
          price: _toDouble(item['price']),
          changePercent: _parsePercent(item['change_percentage']),
          volume: (item['volume'] ?? '-').toString(),
        ),
      )
      .where((e) => e.symbol.trim().isNotEmpty)
      .toList(growable: false);
}

double _toDouble(Object? raw) => double.tryParse(raw?.toString() ?? '') ?? 0;

double _parsePercent(Object? raw) {
  final value = (raw?.toString() ?? '').replaceAll('%', '').trim();
  return double.tryParse(value) ?? 0;
}
