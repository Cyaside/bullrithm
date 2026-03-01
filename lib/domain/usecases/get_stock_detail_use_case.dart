import 'dart:async';

import '../entities/stock_detail_data.dart';
import '../repositories/market_repository.dart';

class GetStockDetailUseCase {
  const GetStockDetailUseCase(this._repository);

  final MarketRepository _repository;

  Future<StockDetailData> call(String symbol) async {
    final responses = await Future.wait<dynamic>([
      _repository.getCompanyOverview(symbol),
      _repository.getDailyTimeSeries(symbol),
    ]);

    return StockDetailData(overview: responses[0], priceSeries: responses[1]);
  }
}
