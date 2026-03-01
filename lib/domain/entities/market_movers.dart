import 'market_mover_item.dart';

class MarketMovers {
  const MarketMovers({
    required this.gainers,
    required this.losers,
    required this.active,
  });

  final List<MarketMoverItem> gainers;
  final List<MarketMoverItem> losers;
  final List<MarketMoverItem> active;
}
