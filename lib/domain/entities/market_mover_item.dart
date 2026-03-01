class MarketMoverItem {
  const MarketMoverItem({
    required this.symbol,
    required this.price,
    required this.changePercent,
    required this.volume,
  });

  final String symbol;
  final double price;
  final double changePercent;
  final String volume;
}
