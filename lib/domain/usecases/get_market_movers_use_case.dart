import '../entities/market_movers.dart';
import '../repositories/market_repository.dart';

class GetMarketMoversUseCase {
  const GetMarketMoversUseCase(this._repository);

  final MarketRepository _repository;

  Future<MarketMovers> call() {
    return _repository.getMarketMovers();
  }
}
