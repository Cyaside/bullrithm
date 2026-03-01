import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/network/alpha_vantage_client.dart';
import '../../data/repositories/alpha_vantage_market_repository.dart';
import '../../domain/domain.dart';

enum StockDetailRefreshResult { completed, throttled }

class StockDetailController extends ChangeNotifier {
  StockDetailController({
    required this.symbol,
    required MarketRepository repository,
    Duration refreshThrottle = const Duration(seconds: 8),
  }) : _repository = repository,
       _refreshThrottle = refreshThrottle;

  factory StockDetailController.fromEnv({required String symbol}) {
    return StockDetailController(
      symbol: symbol,
      repository: AlphaVantageMarketRepository.fromEnv(),
    );
  }

  final String symbol;
  final MarketRepository _repository;
  final Duration _refreshThrottle;
  late final GetStockDetailUseCase _getStockDetailUseCase =
      GetStockDetailUseCase(_repository);

  bool _disposed = false;
  CompanyOverview? _overview;
  List<DailyPricePoint> _priceSeries = const [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastRefreshAt;
  int _requestToken = 0;

  CompanyOverview? get overview => _overview;
  List<DailyPricePoint> get priceSeries => _priceSeries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    await fetchData();
  }

  Future<void> fetchData() async {
    await _fetchData(fromPullToRefresh: false);
  }

  Future<StockDetailRefreshResult> refreshFromPullToRefresh() async {
    return _fetchData(fromPullToRefresh: true);
  }

  Future<StockDetailRefreshResult> _fetchData({
    required bool fromPullToRefresh,
  }) async {
    if (fromPullToRefresh && !_canRefreshNow()) {
      return StockDetailRefreshResult.throttled;
    }

    final currentToken = ++_requestToken;
    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      final detail = await _getStockDetailUseCase(symbol);
      if (_disposed || currentToken != _requestToken) {
        return StockDetailRefreshResult.completed;
      }

      _overview = detail.overview;
      _priceSeries = detail.priceSeries;
    } on AlphaVantageApiException catch (error) {
      if (_disposed || currentToken != _requestToken) {
        return StockDetailRefreshResult.completed;
      }
      _errorMessage = error.message;
    } catch (error) {
      if (_disposed || currentToken != _requestToken) {
        return StockDetailRefreshResult.completed;
      }
      _errorMessage = 'Gagal memuat detail saham: $error';
    } finally {
      if (!_disposed && currentToken == _requestToken) {
        _isLoading = false;
        _notify();
      }
    }

    return StockDetailRefreshResult.completed;
  }

  bool _canRefreshNow() {
    final now = DateTime.now();
    if (_lastRefreshAt == null ||
        now.difference(_lastRefreshAt!) >= _refreshThrottle) {
      _lastRefreshAt = now;
      return true;
    }
    return false;
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
