import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../common/config/app_env.dart';
import '../models/models.dart';

typedef LogFn = void Function(String message);

enum MarketDataProvider { alphaProxy, alphaDirect }

class AlphaVantageClient {
  static const _maxCacheEntries = 200;
  static const _maxPersistedEntries = 120;
  static const _maxPersistedAge = Duration(days: 7);
  static const _persistDebounceDelay = Duration(milliseconds: 900);
  static const _prefsCacheKey = 'alpha_vantage_response_cache_v1';
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
  static Future<void>? _cacheLoadFuture;
  static Timer? _persistDebounceTimer;

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
    _warmUpPersistentCache();
    final effectiveApiKey = AppEnv.effectiveAlphaVantageApiKey;

    if (AppEnv.hasAlphaVantageProxyUrl) {
      return AlphaVantageClient._(
        provider: MarketDataProvider.alphaProxy,
        httpClient: client,
        logger: outputLogger,
        timeout: timeout,
        proxyBaseUrl: AppEnv.alphaVantageProxyUrl.trim(),
        alphaApiKey: effectiveApiKey,
      );
    }

    if (effectiveApiKey != null && effectiveApiKey.isNotEmpty) {
      return AlphaVantageClient._(
        provider: MarketDataProvider.alphaDirect,
        httpClient: client,
        logger: outputLogger,
        timeout: timeout,
        alphaApiKey: effectiveApiKey,
      );
    }

    throw const AlphaVantageApiException(
      'ALPHA_VANTAGE_PROXY_URL or effective ALPHA_VANTAGE_API_KEY is not configured.',
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
    await _ensureCacheLoaded();

    final normalizedParams = <String, String>{
      for (final entry in params.entries) entry.key: entry.value,
    };
    final functionName = (normalizedParams['function'] ?? '')
        .trim()
        .toUpperCase();
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
      _schedulePersistCache();
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
    _trimCacheToLimit(_maxCacheEntries);
  }

  String _buildCacheKey(Map<String, String> params) {
    final pairs = params.entries.toList(growable: false)
      ..sort((a, b) {
        final byKey = a.key.compareTo(b.key);
        if (byKey != 0) return byKey;
        return a.value.compareTo(b.value);
      });

    final encoded = pairs
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    return encoded;
  }

  bool get _canFallbackDirect {
    final runtimeOrCompile = AppEnv.effectiveAlphaVantageApiKey?.trim() ?? '';
    if (runtimeOrCompile.isNotEmpty) return true;
    return _alphaApiKey?.trim().isNotEmpty ?? false;
  }

  static void _warmUpPersistentCache() {
    _cacheLoadFuture ??= _loadCacheFromDisk();
  }

  static Future<void> _ensureCacheLoaded() {
    _cacheLoadFuture ??= _loadCacheFromDisk();
    return _cacheLoadFuture!;
  }

  static Future<void> _loadCacheFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsCacheKey);
      if (raw == null || raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final now = DateTime.now();
      for (final entry in decoded.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value is! Map) continue;

        final mapValue = value.map(
          (innerKey, innerValue) => MapEntry('$innerKey', innerValue),
        );
        final cachedAtRaw = mapValue['cachedAt'];
        final payloadRaw = mapValue['payload'];
        if (cachedAtRaw is! String || payloadRaw is! Map) continue;

        final cachedAt = DateTime.tryParse(cachedAtRaw);
        if (cachedAt == null) continue;
        if (now.difference(cachedAt) > _maxPersistedAge) continue;

        final payload = payloadRaw.map(
          (payloadKey, payloadValue) => MapEntry('$payloadKey', payloadValue),
        );
        _responseCache[key] = _CacheEntry(payload: payload, cachedAt: cachedAt);
      }

      _trimCacheToLimit(_maxCacheEntries);
    } catch (_) {
      // Ignore persistence failures. Network fetch path still works.
    }
  }

  static void _schedulePersistCache() {
    _persistDebounceTimer?.cancel();
    _persistDebounceTimer = Timer(_persistDebounceDelay, () {
      unawaited(_persistCacheToDisk());
    });
  }

  static Future<void> _persistCacheToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _responseCache.entries.toList(growable: false)
        ..sort((a, b) => b.value.cachedAt.compareTo(a.value.cachedAt));

      final limited = entries.take(_maxPersistedEntries);
      final serializable = <String, dynamic>{};
      for (final entry in limited) {
        serializable[entry.key] = <String, dynamic>{
          'cachedAt': entry.value.cachedAt.toIso8601String(),
          'payload': entry.value.payload,
        };
      }

      await prefs.setString(_prefsCacheKey, jsonEncode(serializable));
    } catch (_) {
      // Ignore persistence failures. In-memory cache remains active.
    }
  }

  static void _trimCacheToLimit(int maxEntries) {
    if (_responseCache.length <= maxEntries) return;

    final entries = _responseCache.entries.toList(growable: false)
      ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));

    final deleteCount = _responseCache.length - maxEntries;
    for (var i = 0; i < deleteCount; i++) {
      _responseCache.remove(entries[i].key);
    }
  }

  Future<Map<String, dynamic>> _queryViaProxy(Map<String, String> params) {
    final base = _proxyBaseUrl?.trim() ?? '';
    if (base.isEmpty) {
      throw const AlphaVantageApiException('Proxy base URL not configured.');
    }
    final uri = Uri.parse(base).replace(queryParameters: params);
    return _getJson(uri);
  }

  Future<Map<String, dynamic>> _queryDirect(Map<String, String> params) {
    final key = (AppEnv.effectiveAlphaVantageApiKey?.trim().isNotEmpty ?? false)
        ? AppEnv.effectiveAlphaVantageApiKey!.trim()
        : (_alphaApiKey?.trim() ?? '');
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
      final lowered = info.toLowerCase();
      final isRateLimited =
          lowered.contains('rate limit') ||
          lowered.contains('requests') ||
          lowered.contains('premium');
      throw AlphaVantageApiException(info, isRateLimit: isRateLimited);
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
