import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/network/alpha_vantage_client.dart';
import '../../data/repositories/alpha_vantage_market_repository.dart';
import '../../domain/domain.dart';

enum NewsSentimentFilter {
  all('All'),
  bullish('Bullish'),
  somewhatBullish('Somewhat Bullish'),
  neutral('Neutral'),
  somewhatBearish('Somewhat Bearish'),
  bearish('Bearish');

  const NewsSentimentFilter(this.label);
  final String label;
}

enum SentimentBucket {
  bullish('BULLISH'),
  somewhatBullish('SOMEWHAT BULLISH'),
  neutral('NEUTRAL'),
  somewhatBearish('SOMEWHAT BEARISH'),
  bearish('BEARISH');

  const SentimentBucket(this.label);
  final String label;
}

class NewsSentimentController extends ChangeNotifier {
  NewsSentimentController({required MarketRepository repository})
    : _repository = repository;

  factory NewsSentimentController.fromEnv() {
    return NewsSentimentController(
      repository: AlphaVantageMarketRepository.fromEnv(),
    );
  }

  final MarketRepository _repository;
  late final GetNewsSentimentUseCase _getNewsSentimentUseCase =
      GetNewsSentimentUseCase(_repository);

  bool _disposed = false;
  List<NewsItem> _items = const [];
  NewsSentimentFilter _filter = NewsSentimentFilter.all;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastUpdated;
  int _requestToken = 0;

  List<NewsItem> get items => _items;
  NewsSentimentFilter get filter => _filter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastUpdated => _lastUpdated;

  List<NewsItem> get filteredItems {
    if (_filter == NewsSentimentFilter.all) return _items;
    return _items
        .where((item) => matchesFilter(classifySentiment(item), _filter))
        .toList(growable: false);
  }

  Future<void> initialize() async {
    await fetchNews();
  }

  void setFilter(NewsSentimentFilter value) {
    if (_filter == value) return;
    _filter = value;
    _notify();
  }

  Future<void> fetchNews() async {
    final currentToken = ++_requestToken;
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      final result = await _getNewsSentimentUseCase(limit: 1000);
      if (_disposed || currentToken != _requestToken) return;
      _items = result;
      _lastUpdated = DateTime.now();
    } on AlphaVantageApiException catch (error) {
      if (_disposed || currentToken != _requestToken) return;
      _errorMessage = error.message;
    } catch (_) {
      if (_disposed || currentToken != _requestToken) return;
      _errorMessage = 'Gagal memuat berita dan sentimen.';
    } finally {
      if (!_disposed && currentToken == _requestToken) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _repository.dispose();
    super.dispose();
  }
}

bool matchesFilter(SentimentBucket bucket, NewsSentimentFilter filter) {
  switch (filter) {
    case NewsSentimentFilter.all:
      return true;
    case NewsSentimentFilter.bullish:
      return bucket == SentimentBucket.bullish;
    case NewsSentimentFilter.somewhatBullish:
      return bucket == SentimentBucket.somewhatBullish;
    case NewsSentimentFilter.neutral:
      return bucket == SentimentBucket.neutral;
    case NewsSentimentFilter.somewhatBearish:
      return bucket == SentimentBucket.somewhatBearish;
    case NewsSentimentFilter.bearish:
      return bucket == SentimentBucket.bearish;
  }
}

SentimentBucket classifySentiment(NewsItem item) {
  final rawLabel = item.overallSentimentLabel.trim().toUpperCase();
  final normalized = rawLabel
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (normalized.contains('SOMEWHAT BULLISH')) {
    return SentimentBucket.somewhatBullish;
  }
  if (normalized == 'BULLISH') return SentimentBucket.bullish;
  if (normalized.contains('SOMEWHAT BEARISH')) {
    return SentimentBucket.somewhatBearish;
  }
  if (normalized == 'BEARISH') return SentimentBucket.bearish;
  if (normalized == 'NEUTRAL') return SentimentBucket.neutral;

  final score = item.overallSentimentScore ?? 0;
  if (score >= 0.35) return SentimentBucket.bullish;
  if (score > 0.05) return SentimentBucket.somewhatBullish;
  if (score <= -0.35) return SentimentBucket.bearish;
  if (score < -0.05) return SentimentBucket.somewhatBearish;
  return SentimentBucket.neutral;
}
