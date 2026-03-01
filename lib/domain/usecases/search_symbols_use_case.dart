import '../../data/models/models.dart';
import '../repositories/market_repository.dart';

class SearchSymbolsUseCase {
  const SearchSymbolsUseCase(this._repository);

  final MarketRepository _repository;

  Future<List<SearchResultItem>> call(String keywords) {
    return _repository.searchSymbols(keywords);
  }
}
