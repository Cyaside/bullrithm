import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../common/config/app_env.dart';
import '../models/models.dart';

typedef LogFn = void Function(String message);

enum MarketDataProvider { alphaProxy, alphaDirect, yahooDirect }

class AlphaVantageClient {
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

    return AlphaVantageClient._(
      provider: MarketDataProvider.yahooDirect,
      httpClient: client,
      logger: outputLogger,
      timeout: timeout,
    );
  }

  final MarketDataProvider _provider;
  final http.Client _httpClient;
  final LogFn _logger;
  final Duration _timeout;
  final String? _proxyBaseUrl;
  final String? _alphaApiKey;

  Future<List<SearchResultItem>> searchSymbols(String keywords) {
    final trimmed = keywords.trim();
    if (trimmed.isEmpty) return Future.value(const []);

    return _callWithFallback<List<SearchResultItem>>(
      alphaCall: () async {
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
      },
      yahooCall: () async {
        final uri = Uri.https(
          'query1.finance.yahoo.com',
          '/v1/finance/search',
          <String, String>{'q': trimmed, 'quotesCount': '20', 'newsCount': '0'},
        );
        final json = await _getJson(uri);
        final quotes = (json['quotes'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
            .toList(growable: false);

        return quotes.map(_searchItemFromYahoo).toList(growable: false);
      },
    );
  }

  Future<CompanyOverview> fetchCompanyOverview(String symbol) {
    final normalized = symbol.trim().toUpperCase();

    return _callWithFallback<CompanyOverview>(
      alphaCall: () async {
        final json = await _alphaQuery(<String, String>{
          'function': 'OVERVIEW',
          'symbol': normalized,
        });
        return CompanyOverview.fromAlphaVantage(json);
      },
      yahooCall: () async {
        final uri = Uri.https(
          'query1.finance.yahoo.com',
          '/v10/finance/quoteSummary/$normalized',
          <String, String>{
            'modules': 'price,summaryProfile,assetProfile,defaultKeyStatistics',
          },
        );
        final json = await _getJson(uri);

        final result =
            (((json['quoteSummary'] as Map?)?['result'] as List?) ?? const [])
                .whereType<Map>()
                .cast<Map<dynamic, dynamic>>()
                .map(
                  (entry) => entry.map((key, value) => MapEntry('$key', value)),
                )
                .toList(growable: false);

        if (result.isEmpty) {
          return CompanyOverview(
            symbol: normalized,
            name: '',
            description: '',
            sector: '',
            industry: '',
            marketCapitalization: null,
            peRatio: null,
            currency: '',
            country: '',
            exchange: '',
          );
        }

        final node = result.first;
        final price = _asMap(node['price']);
        final summaryProfile = _asMap(node['summaryProfile']);
        final assetProfile = _asMap(node['assetProfile']);
        final keyStats = _asMap(node['defaultKeyStatistics']);

        return CompanyOverview(
          symbol: normalized,
          name: _readString(
            price['longName'] ??
                price['shortName'] ??
                summaryProfile['longBusinessSummary'],
          ),
          description: _readString(
            summaryProfile['longBusinessSummary'] ??
                assetProfile['longBusinessSummary'],
          ),
          sector: _readString(assetProfile['sector']),
          industry: _readString(assetProfile['industry']),
          marketCapitalization: _readIntRaw(price['marketCap']),
          peRatio: _readDoubleRaw(
            keyStats['trailingPE'] ??
                keyStats['forwardPE'] ??
                price['trailingPE'],
          ),
          currency: _readString(price['currency']),
          country: _readString(
            assetProfile['country'] ?? summaryProfile['country'],
          ),
          exchange: _readString(
            price['exchangeName'] ?? price['fullExchangeName'],
          ),
        );
      },
    );
  }

  Future<List<DailyPricePoint>> fetchDailyTimeSeries(String symbol) {
    final normalized = symbol.trim().toUpperCase();

    return _callWithFallback<List<DailyPricePoint>>(
      alphaCall: () async {
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
                json: value.map(
                  (key, innerValue) => MapEntry('$key', innerValue),
                ),
              ),
            );
          }
        }

        points.sort((a, b) => a.date.compareTo(b.date));
        return points;
      },
      yahooCall: () async {
        final uri = Uri.https(
          'query1.finance.yahoo.com',
          '/v8/finance/chart/$normalized',
          <String, String>{'interval': '1d', 'range': '6mo'},
        );
        final json = await _getJson(uri);

        final result =
            (((json['chart'] as Map?)?['result'] as List?) ?? const [])
                .whereType<Map>()
                .cast<Map<dynamic, dynamic>>()
                .map(
                  (entry) => entry.map((key, value) => MapEntry('$key', value)),
                )
                .toList(growable: false);
        if (result.isEmpty) return const [];

        final node = result.first;
        final timestamps = ((node['timestamp'] as List?) ?? const [])
            .map((e) => int.tryParse(e.toString()))
            .toList(growable: false);
        final indicators = _asMap(node['indicators']);
        final quoteList = (indicators['quote'] as List?) ?? const [];
        if (quoteList.isEmpty) return const [];

        final quote = _asMap(quoteList.first);
        final opens = (quote['open'] as List?) ?? const [];
        final highs = (quote['high'] as List?) ?? const [];
        final lows = (quote['low'] as List?) ?? const [];
        final closes = (quote['close'] as List?) ?? const [];
        final volumes = (quote['volume'] as List?) ?? const [];

        final count = <int>[
          timestamps.length,
          opens.length,
          highs.length,
          lows.length,
          closes.length,
          volumes.length,
        ].reduce((a, b) => a < b ? a : b);

        final points = <DailyPricePoint>[];
        for (var i = 0; i < count; i++) {
          final ts = timestamps[i];
          if (ts == null) continue;

          points.add(
            DailyPricePoint(
              date: DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true),
              open: _toDouble(opens[i]),
              high: _toDouble(highs[i]),
              low: _toDouble(lows[i]),
              close: _toDouble(closes[i]),
              volume: _toInt(volumes[i]),
            ),
          );
        }

        points.sort((a, b) => a.date.compareTo(b.date));
        return points;
      },
    );
  }

  Future<List<NewsItem>> fetchNewsSentiment({String? ticker, int limit = 20}) {
    final normalizedTicker = ticker?.trim().toUpperCase();

    return _callWithFallback<List<NewsItem>>(
      alphaCall: () async {
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
      },
      yahooCall: () async {
        final query = (normalizedTicker == null || normalizedTicker.isEmpty)
            ? 'market'
            : normalizedTicker;
        final uri = Uri.https(
          'query1.finance.yahoo.com',
          '/v1/finance/search',
          <String, String>{
            'q': query,
            'quotesCount': '0',
            'newsCount': '$limit',
          },
        );
        final json = await _getJson(uri);
        final news = (json['news'] as List<dynamic>? ?? const [])
            .whereType<Map<dynamic, dynamic>>()
            .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
            .toList(growable: false);

        return news.map(_newsFromYahoo).toList(growable: false);
      },
    );
  }

  Future<Map<String, dynamic>> fetchTopGainersLosers() {
    return _callWithFallback<Map<String, dynamic>>(
      alphaCall: () =>
          _alphaQuery(<String, String>{'function': 'TOP_GAINERS_LOSERS'}),
      yahooCall: () async {
        final gainers = await _fetchYahooScreener('day_gainers');
        final losers = await _fetchYahooScreener('day_losers');
        final active = await _fetchYahooScreener('most_actives');

        return <String, dynamic>{
          'top_gainers': gainers,
          'top_losers': losers,
          'most_actively_traded': active,
        };
      },
    );
  }

  Future<T> _callWithFallback<T>({
    required Future<T> Function() alphaCall,
    required Future<T> Function() yahooCall,
  }) async {
    if (_provider == MarketDataProvider.yahooDirect) {
      return yahooCall();
    }

    try {
      return await alphaCall();
    } on AlphaVantageApiException catch (error) {
      if (error.isRateLimit) {
        _logger('Alpha rate limited. Falling back to Yahoo.');
        return yahooCall();
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchYahooScreener(
    String screenerId,
  ) async {
    final uri = Uri.https(
      'query1.finance.yahoo.com',
      '/v1/finance/screener/predefined/saved',
      <String, String>{'count': '20', 'scrIds': screenerId},
    );
    final json = await _getJson(uri);
    final results =
        (((json['finance'] as Map?)?['result'] as List?) ?? const [])
            .whereType<Map>()
            .toList(growable: false);
    if (results.isEmpty) return const [];

    final quotes = (results.first['quotes'] as List?) ?? const [];
    return quotes
        .whereType<Map>()
        .map((q) {
          final symbol = _readString(q['symbol']);
          final price = _readDoubleRaw(q['regularMarketPrice']) ?? 0;
          final changePct =
              _readDoubleRaw(q['regularMarketChangePercent']) ?? 0;
          final volume = _readIntRaw(q['regularMarketVolume']) ?? 0;
          return <String, dynamic>{
            'ticker': symbol,
            'price': price.toStringAsFixed(2),
            'change_percentage': '${changePct.toStringAsFixed(2)}%',
            'volume': volume.toString(),
          };
        })
        .where((e) => (e['ticker'] as String).isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _alphaQuery(Map<String, String> params) async {
    if (_provider == MarketDataProvider.alphaProxy) {
      final base = _proxyBaseUrl;
      if (base == null || base.isEmpty) {
        throw const AlphaVantageApiException('Proxy base URL not configured.');
      }
      final uri = Uri.parse(base).replace(queryParameters: params);
      return _getJson(uri);
    }

    if (_provider == MarketDataProvider.alphaDirect) {
      final key = _alphaApiKey;
      if (key == null || key.isEmpty) {
        throw const AlphaVantageApiException('Alpha API key not configured.');
      }
      final queryParams = <String, String>{...params, 'apikey': key};
      final uri = Uri.https('www.alphavantage.co', '/query', queryParams);
      return _getJson(uri);
    }

    throw const AlphaVantageApiException('Alpha provider is not enabled.');
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    _logger('GET $uri');

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

SearchResultItem _searchItemFromYahoo(Map<String, dynamic> q) {
  final symbol = _readString(q['symbol']);
  final name = _readString(q['shortname'] ?? q['longname'] ?? q['name']);
  final region = _readString(q['exchDisp'] ?? q['exchange']);
  final currency = _readString(q['currency']);
  final type = _readString(q['typeDisp'] ?? q['quoteType']);

  return SearchResultItem(
    symbol: symbol,
    name: name,
    region: region,
    currency: currency,
    type: type,
    matchScore: null,
  );
}

NewsItem _newsFromYahoo(Map<String, dynamic> n) {
  final timeSec = int.tryParse((n['providerPublishTime'] ?? '').toString());
  final dt = timeSec == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(timeSec * 1000, isUtc: true);
  return NewsItem(
    title: _readString(n['title']),
    source: _readString(n['publisher']),
    url: _readString(n['link']),
    summary: _readString(n['summary']),
    timePublished: dt,
    overallSentimentScore: null,
    overallSentimentLabel: 'Neutral',
  );
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry('$key', val));
  }
  return const <String, dynamic>{};
}

String _readString(Object? raw) => raw?.toString().trim() ?? '';

int? _readIntRaw(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toInt();
  if (raw is Map) {
    final v = raw['raw'];
    if (v is num) return v.toInt();
  }
  return int.tryParse(raw.toString());
}

double? _readDoubleRaw(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is Map) {
    final v = raw['raw'];
    if (v is num) return v.toDouble();
  }
  return double.tryParse(raw.toString());
}

double _toDouble(Object? raw) => _readDoubleRaw(raw) ?? 0;

int _toInt(Object? raw) => _readIntRaw(raw) ?? 0;
