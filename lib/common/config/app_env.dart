class AppEnv {
  AppEnv._();

  static const alphaVantageApiKey = String.fromEnvironment(
    'ALPHA_VANTAGE_API_KEY',
  );
  static const alphaVantageProxyUrl = String.fromEnvironment(
    'ALPHA_VANTAGE_PROXY_URL',
  );

  static bool get hasAlphaVantageApiKey => alphaVantageApiKey.trim().isNotEmpty;
  static bool get hasAlphaVantageProxyUrl =>
      alphaVantageProxyUrl.trim().isNotEmpty;
}
