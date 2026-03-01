import '../../data/models/models.dart';
import '../repositories/market_repository.dart';

class GetNewsSentimentUseCase {
  const GetNewsSentimentUseCase(this._repository);

  final MarketRepository _repository;

  Future<List<NewsItem>> call({String? ticker, int limit = 1000}) {
    return _repository.getNewsSentiment(ticker: ticker, limit: limit);
  }
}
