class DailyPricePoint {
  const DailyPricePoint({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  factory DailyPricePoint.fromAlphaVantage({
    required String dateKey,
    required Map<String, dynamic> json,
  }) {
    return DailyPricePoint(
      date: DateTime.parse(dateKey),
      open: _toDouble(json['1. open']),
      high: _toDouble(json['2. high']),
      low: _toDouble(json['3. low']),
      close: _toDouble(json['4. close']),
      volume: _toInt(json['5. volume']),
    );
  }
}

double _toDouble(Object? value) => double.tryParse(value.toString()) ?? 0;

int _toInt(Object? value) => int.tryParse(value.toString()) ?? 0;
