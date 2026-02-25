import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../common/config/app_env.dart';
import '../models/models.dart';

typedef LogFn = void Function(String message);

class AlphaVantageClient {
  AlphaVantageClient({
    http.Client? httpClient,
    required String apiKey,
    this.timeout = const Duration(seconds: 12),
    this.baseUrl = 'https://www.alphavantage.co/query',
    LogFn? logger,
  }) : _httpClient = httpClient ?? http.Client(),
       _apiKey = apiKey,
       _logger = logger ?? _defaultLogger;

  factory AlphaVantageClient.fromEnv({http.Client? httpClient, LogFn? logger}) {
    final apiKey = AppEnv.alphaVantageApiKey;
    if (apiKey == null) {
      throw const AlphaVantageApiException(
        'Missing Alpha Vantage API key. Add ALPHA_VANTAGE_API_KEY to .env',
      );
    }

    return AlphaVantageClient(
      httpClient: httpClient,
      apiKey: apiKey,
      logger: logger,
    );
  }

  final http.Client _httpClient;
  final String _apiKey;
  final Duration timeout;
  final String baseUrl;
  final LogFn _logger;

  Future<List<SearchResultItem>> searchSymbols(String keywords) async {
    final trimmed = keywords.trim();
    if (trimmed.isEmpty) return const [];

    final json = await _get(<String, String>{
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
    final json = await _get(<String, String>{
      'function': 'OVERVIEW',
      'symbol': symbol.trim().toUpperCase(),
    });

    return CompanyOverview.fromAlphaVantage(json);
  }

  Future<List<DailyPricePoint>> fetchDailyTimeSeries(String symbol) async {
    final json = await _get(<String, String>{
      'function': 'TIME_SERIES_DAILY',
      'symbol': symbol.trim().toUpperCase(),
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
    int limit = 20,
  }) async {
    final params = <String, String>{
      'function': 'NEWS_SENTIMENT',
      'limit': '$limit',
    };

    if (ticker != null && ticker.trim().isNotEmpty) {
      params['tickers'] = ticker.trim().toUpperCase();
    }

    final json = await _get(params);
    final feed = (json['feed'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((entry) => entry.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);

    return feed.map(NewsItem.fromAlphaVantage).toList(growable: false);
  }

  Future<Map<String, dynamic>> fetchTopGainersLosers() async {
    return _get(<String, String>{'function': 'TOP_GAINERS_LOSERS'});
  }

  Future<Map<String, dynamic>> _get(Map<String, String> params) async {
    final queryParams = <String, String>{...params, 'apikey': _apiKey};
    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

    _logger('GET $uri');

    http.Response response;
    try {
      response = await _httpClient.get(uri).timeout(timeout);
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
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AlphaVantageApiException(
        'Unexpected response format from Alpha Vantage.',
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
    developer.log(message, name: 'AlphaVantageClient');
  }
}

class AlphaVantageApiException implements Exception {
  const AlphaVantageApiException(this.message, {this.isRateLimit = false});

  final String message;
  final bool isRateLimit;

  @override
  String toString() {
    return 'AlphaVantageApiException(message: $message, isRateLimit: $isRateLimit)';
  }
}
