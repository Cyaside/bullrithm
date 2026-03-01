import '../../data/models/models.dart';
import '../entities/market_movers.dart';

abstract class MarketRepository {
  Future<List<SearchResultItem>> searchSymbols(String keywords);

  Future<MarketMovers> getMarketMovers();

  Future<CompanyOverview> getCompanyOverview(String symbol);

  Future<List<DailyPricePoint>> getDailyTimeSeries(String symbol);

  Future<List<NewsItem>> getNewsSentiment({String? ticker, int limit = 1000});

  void dispose();
}
