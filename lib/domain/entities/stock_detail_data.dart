import '../../data/models/models.dart';

class StockDetailData {
  const StockDetailData({required this.overview, required this.priceSeries});

  final CompanyOverview overview;
  final List<DailyPricePoint> priceSeries;
}
