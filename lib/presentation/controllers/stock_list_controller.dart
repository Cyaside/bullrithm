import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/network/alpha_vantage_client.dart';
import '../../data/repositories/alpha_vantage_market_repository.dart';
import '../../domain/domain.dart';

enum MarketMoverTab { gainers, losers, active }

class StockListController extends ChangeNotifier {
  StockListController({
    required MarketRepository repository,
    Duration debounceDuration = const Duration(milliseconds: 600),
  }) : _repository = repository,
       _debounceDuration = debounceDuration;

  factory StockListController.fromEnv() {
    return StockListController(
      repository: AlphaVantageMarketRepository.fromEnv(),
    );
  }

  static const _maxRecentQueries = 10;

  final MarketRepository _repository;
  final Duration _debounceDuration;
  final _queryCache = <String, List<SearchResultItem>>{};
  final _recentQueries = <String>[];
  late final SearchSymbolsUseCase _searchSymbolsUseCase = SearchSymbolsUseCase(
    _repository,
  );
  late final GetMarketMoversUseCase _getMarketMoversUseCase =
      GetMarketMoversUseCase(_repository);

  Timer? _debounce;
  bool _disposed = false;
  bool _isLoading = false;
  bool _isMoversLoading = false;
  String? _errorMessage;
  String? _moversErrorMessage;
  List<SearchResultItem> _results = const [];
  int _requestToken = 0;
  MarketMoverTab _selectedMoverTab = MarketMoverTab.gainers;
  List<MarketMoverItem> _gainers = const [];
  List<MarketMoverItem> _losers = const [];
  List<MarketMoverItem> _active = const [];
  String _query = '';

  bool get isLoading => _isLoading;
  bool get isMoversLoading => _isMoversLoading;
  String? get errorMessage => _errorMessage;
  String? get moversErrorMessage => _moversErrorMessage;
  List<SearchResultItem> get results => _results;
  String get query => _query;
  List<String> get recentQueries => List.unmodifiable(_recentQueries);
  MarketMoverTab get selectedMoverTab => _selectedMoverTab;

  List<MarketMoverItem> get selectedMovers {
    switch (_selectedMoverTab) {
      case MarketMoverTab.gainers:
        return _gainers;
      case MarketMoverTab.losers:
        return _losers;
      case MarketMoverTab.active:
        return _active;
    }
  }

  Future<void> initialize() async {
    await fetchMovers();
  }

  void onQueryChanged(String value) {
    _query = value;
    _notify();

    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => search(_query));
  }

  void clearQuery() {
    onQueryChanged('');
  }

  void selectMoverTab(MarketMoverTab tab) {
    if (_selectedMoverTab == tab) return;
    _selectedMoverTab = tab;
    _notify();
  }

  Future<void> search(String query) async {
    final normalized = query.trim();

    if (normalized.isEmpty) {
      _isLoading = false;
      _errorMessage = null;
      _results = const [];
      _notify();
      return;
    }

    final cacheKey = normalized.toLowerCase();
    final cached = _queryCache[cacheKey];
    _isLoading = true;
    _errorMessage = null;
    if (cached != null) {
      _results = cached;
    }
    _notify();

    final currentToken = ++_requestToken;
    try {
      final fresh = await _searchSymbolsUseCase(normalized);
      if (_disposed || currentToken != _requestToken) return;

      _queryCache[cacheKey] = fresh;
      _rememberQuery(normalized);
      _results = fresh;
    } on AlphaVantageApiException catch (error) {
      if (_disposed || currentToken != _requestToken) return;

      final fallback = _queryCache[cacheKey] ?? const <SearchResultItem>[];
      _results = fallback;
      if (fallback.isNotEmpty && error.isRateLimit) {
        _errorMessage = 'Rate limit terkena, menampilkan hasil cache.';
      } else {
        _errorMessage = error.message;
      }
    } catch (_) {
      if (_disposed || currentToken != _requestToken) return;
      _errorMessage = 'Terjadi kesalahan saat memuat data saham.';
    } finally {
      if (!_disposed && currentToken == _requestToken) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> fetchMovers() async {
    _isMoversLoading = true;
    _moversErrorMessage = null;
    _notify();

    try {
      final movers = await _getMarketMoversUseCase();
      if (_disposed) return;

      _gainers = movers.gainers;
      _losers = movers.losers;
      _active = movers.active;
    } on AlphaVantageApiException catch (error) {
      if (_disposed) return;
      _moversErrorMessage = error.message;
    } catch (_) {
      if (_disposed) return;
      _moversErrorMessage = 'Gagal memuat market movers.';
    } finally {
      if (!_disposed) {
        _isMoversLoading = false;
        _notify();
      }
    }
  }

  void _rememberQuery(String query) {
    _recentQueries.remove(query);
    _recentQueries.insert(0, query);
    if (_recentQueries.length > _maxRecentQueries) {
      _recentQueries.removeRange(_maxRecentQueries, _recentQueries.length);
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
