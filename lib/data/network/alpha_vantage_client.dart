import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../common/config/app_env.dart';
import '../models/models.dart';

typedef LogFn = void Function(String message);

enum MarketDataProvider { alphaProxy, alphaDirect }

class AlphaVantageClient {
  static const _maxCacheEntries = 200;
  static const _defaultCacheTtl = Duration(minutes: 2);
  static const Map<String, Duration> _cacheTtlByFunction = <String, Duration>{
    'SYMBOL_SEARCH': Duration(hours: 6),
    'OVERVIEW': Duration(hours: 24),
    'TIME_SERIES_DAILY': Duration(hours: 2),
    'NEWS_SENTIMENT': Duration(minutes: 10),
    'TOP_GAINERS_LOSERS': Duration(minutes: 5),
    'GLOBAL_QUOTE': Duration(minutes: 1),
  };
  static final Map<String, _CacheEntry> _responseCache =
      <String, _CacheEntry>{};
  static final Map<String, Future<Map<String, dynamic>>> _inFlightRequests =
      <String, Future<Map<String, dynamic>>>{};

  AlphaVantageClient._({
    required MarketDataProvider provider,
    required http.Client httpClient,
    required LogFn logger,
    required Duration timeout,
    String? proxyBaseUrl,
    String? alphaApiKey,
  }) : _provider = provider,
       _httpClient = httpClient,
       _logger = logger,
       _timeout = timeout,
       _proxyBaseUrl = proxyBaseUrl,
       _alphaApiKey = alphaApiKey;

  factory AlphaVantageClient.fromEnv({
    http.Client? httpClient,
    LogFn? logger,
    Duration timeout = const Duration(seconds: 12),
  }) {
    final client = httpClient ?? http.Client();
    final outputLogger = logger ?? _defaultLogger;

    if (AppEnv.hasAlphaVantageProxyUrl) {
      return AlphaVantageClient._(
        provider: MarketDataProvider.alphaProxy,
        httpClient: client,
        logger: outputLogger,
        timeout: timeout,
        proxyBaseUrl: AppEnv.alphaVantageProxyUrl.trim(),
        alphaApiKey: AppEnv.hasAlphaVantageApiKey
            ? AppEnv.alphaVantageApiKey.trim()
            : null,
      );
    }

    if (AppEnv.hasAlphaVantageApiKey) {
      return AlphaVantageClient._(
        provider: MarketDataProvider.alphaDirect,
        httpClient: client,
        logger: outputLogger,
        timeout: timeout,
        alphaApiKey: AppEnv.alphaVantageApiKey.trim(),
      );
    }

    throw const AlphaVantageApiException(
      'ALPHA_VANTAGE_PROXY_URL or ALPHA_VANTAGE_API_KEY is not configured.',
    );
  }

  final MarketDataProvider _provider;
  final http.Client _httpClient;
  final LogFn _logger;
  final Duration _timeout;
  final String? _proxyBaseUrl;
  final String? _alphaApiKey;

  Future<List<SearchResultItem>> searchSymbols(String keywords) async {
    final trimmed = keywords.trim();
    if (trimmed.isEmpty) return Future.value(const []);

    final json = await _alphaQuery(<String, String>{
      'function': 'SYMBOL_SEARCH',
      'keywords': trimmed,
    });

    final matches = (json['bestMatches'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);

    return matches
        .map(SearchResultItem.fromAlphaVantage)
        .toList(growable: false);
  }

  Future<CompanyOverview> fetchCompanyOverview(String symbol) async {
    final normalized = symbol.trim().toUpperCase();
    final json = await _alphaQuery(<String, String>{
      'function': 'OVERVIEW',
      'symbol': normalized,
    });
    return CompanyOverview.fromAlphaVantage(json);
  }

  Future<List<DailyPricePoint>> fetchDailyTimeSeries(String symbol) async {
    final normalized = symbol.trim().toUpperCase();
    final json = await _alphaQuery(<String, String>{
      'function': 'TIME_SERIES_DAILY',
      'symbol': normalized,
    });

    final rawSeries =
        (json['Time Series (Daily)'] as Map<String, dynamic>? ??
        const <String, dynamic>{});
    final points = <DailyPricePoint>[];

    for (final entry in rawSeries.entries) {
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        points.add(
          DailyPricePoint.fromAlphaVantage(dateKey: entry.key, json: value),
        );
      } else if (value is Map) {
        points.add(
          DailyPricePoint.fromAlphaVantage(
            dateKey: entry.key,
            json: value.map((key, innerValue) => MapEntry('$key', innerValue)),
          ),
        );
      }
    }

    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  Future<List<NewsItem>> fetchNewsSentiment({
    String? ticker,
    int limit = 1000,
  }) async {
    final normalizedTicker = ticker?.trim().toUpperCase();

    final params = <String, String>{
      'function': 'NEWS_SENTIMENT',
      'limit': '$limit',
    };
    if (normalizedTicker != null && normalizedTicker.isNotEmpty) {
      params['tickers'] = normalizedTicker;
    }

    final json = await _alphaQuery(params);
    final feed = (json['feed'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
    return feed.map(NewsItem.fromAlphaVantage).toList(growable: false);
  }

  Future<Map<String, dynamic>> fetchTopGainersLosers() {
    return _alphaQuery(<String, String>{'function': 'TOP_GAINERS_LOSERS'});
  }

  Future<Map<String, dynamic>> _alphaQuery(Map<String, String> params) async {
    final normalizedParams = <String, String>{
      for (final entry in params.entries) entry.key: entry.value,
    };
    final functionName =
        (normalizedParams['function'] ?? '').trim().toUpperCase();
    if (functionName.isNotEmpty) {
      normalizedParams['function'] = functionName;
    }

    final cacheKey = _buildCacheKey(normalizedParams);
    final ttl = _cacheTtlByFunction[functionName] ?? _defaultCacheTtl;
    final now = DateTime.now();
    final cached = _responseCache[cacheKey];
    if (cached != null && now.isBefore(cached.cachedAt.add(ttl))) {
      _logger('CACHE HIT $functionName');
      return cached.payload;
    }

    final inflight = _inFlightRequests[cacheKey];
    if (inflight != null) {
      _logger('IN-FLIGHT REUSE $functionName');
      return inflight;
    }

    final requestFuture = _queryAndCache(
      normalizedParams,
      cacheKey: cacheKey,
      functionName: functionName,
      staleCache: cached,
    );
    _inFlightRequests[cacheKey] = requestFuture;

    try {
      return await requestFuture;
    } finally {
      _inFlightRequests.remove(cacheKey);
    }
  }

  Future<Map<String, dynamic>> _queryAndCache(
    Map<String, String> params, {
    required String cacheKey,
    required String functionName,
    required _CacheEntry? staleCache,
  }) async {
    try {
      final result = await _queryFromNetwork(params);
      _responseCache[cacheKey] = _CacheEntry(
        payload: result,
        cachedAt: DateTime.now(),
      );
      _evictCacheIfNeeded();
      return result;
    } on AlphaVantageApiException catch (error) {
      if (staleCache != null) {
        _logger(
          'Serving stale cache for $functionName after error: ${error.message}',
        );
        return staleCache.payload;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _queryFromNetwork(Map<String, String> params) {
    if (_provider == MarketDataProvider.alphaProxy) {
      return _queryWithProxyFallback(params);
    }

    return _queryDirect(params);
  }

  Future<Map<String, dynamic>> _queryWithProxyFallback(
    Map<String, String> params,
  ) async {
    try {
      return await _queryViaProxy(params);
    } on AlphaVantageApiException catch (error) {
      if (error.isRateLimit) {
        rethrow;
      }
      if (_canFallbackDirect) {
        _logger(
          'Proxy request failed (${error.message}). Falling back to direct Alpha Vantage.',
        );
        return _queryDirect(params);
      }
      rethrow;
    }
  }

  void _evictCacheIfNeeded() {
    if (_responseCache.length <= _maxCacheEntries) return;
    final oldestEntry = _responseCache.entries.reduce(
      (currentOldest, entry) =>
          entry.value.cachedAt.isBefore(currentOldest.value.cachedAt)
          ? entry
          : currentOldest,
    );
    _responseCache.remove(oldestEntry.key);
  }

  String _buildCacheKey(Map<String, String> params) {
    final pairs = params.entries.toList(growable: false)
      ..sort((a, b) {
        final byKey = a.key.compareTo(b.key);
        if (byKey != 0) return byKey;
        return a.value.compareTo(b.value);
      });

    final encoded = pairs
        .map((entry) => '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&');
    return encoded;
  }

  bool get _canFallbackDirect => _alphaApiKey?.trim().isNotEmpty ?? false;

  Future<Map<String, dynamic>> _queryViaProxy(Map<String, String> params) {
    final base = _proxyBaseUrl?.trim() ?? '';
    if (base.isEmpty) {
      throw const AlphaVantageApiException('Proxy base URL not configured.');
    }
    final uri = Uri.parse(base).replace(queryParameters: params);
    return _getJson(uri);
  }

  Future<Map<String, dynamic>> _queryDirect(Map<String, String> params) {
    final key = _alphaApiKey?.trim() ?? '';
    if (key.isEmpty) {
      throw const AlphaVantageApiException('Alpha API key not configured.');
    }
    final queryParams = <String, String>{...params, 'apikey': key};
    final uri = Uri.https('www.alphavantage.co', '/query', queryParams);
    return _getJson(uri);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    _logger('GET ${_sanitizeUriForLog(uri)}');

    http.Response response;
    try {
      response = await _httpClient
          .get(
            uri,
            headers: const <String, String>{
              'Accept': 'application/json',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AlphaVantageApiException(
        'Request timeout. Please try again.',
      );
    } on http.ClientException catch (error) {
      throw AlphaVantageApiException('Network error: ${error.message}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AlphaVantageApiException(
        'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}',
        isRateLimit: response.statusCode == 429,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AlphaVantageApiException('Unexpected response format.');
    }

    final error = decoded['error'];
    if (error is String && error.trim().isNotEmpty) {
      final lowered = error.toLowerCase();
      throw AlphaVantageApiException(
        error,
        isRateLimit: lowered.contains('rate limit'),
      );
    }

    final errorMessage = decoded['Error Message'] as String?;
    if (errorMessage != null && errorMessage.isNotEmpty) {
      throw AlphaVantageApiException(errorMessage);
    }

    final note = decoded['Note'] as String?;
    if (note != null && note.isNotEmpty) {
      throw AlphaVantageApiException(note, isRateLimit: true);
    }

    final info = decoded['Information'] as String?;
    if (info != null && info.isNotEmpty) {
      throw AlphaVantageApiException(info);
    }

    return decoded;
  }

  Uri _sanitizeUriForLog(Uri uri) {
    if (!uri.queryParameters.containsKey('apikey')) return uri;
    final sanitized = Map<String, String>.from(uri.queryParameters)
      ..['apikey'] = '***';
    return uri.replace(queryParameters: sanitized);
  }

  void dispose() {
    _httpClient.close();
  }

  static void _defaultLogger(String message) {
    developer.log(message, name: 'MarketDataClient');
  }
}

class AlphaVantageApiException implements Exception {
  const AlphaVantageApiException(this.message, {this.isRateLimit = false});

  final String message;
  final bool isRateLimit;

  @override
  String toString() =>
      'AlphaVantageApiException(message: $message, isRateLimit: $isRateLimit)';
}

class _CacheEntry {
  const _CacheEntry({required this.payload, required this.cachedAt});

  final Map<String, dynamic> payload;
  final DateTime cachedAt;
}
