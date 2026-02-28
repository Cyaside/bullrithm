class AppEnv {
  AppEnv._();

  static const alphaVantageProxyUrl = String.fromEnvironment(
    'ALPHA_VANTAGE_PROXY_URL',
  );

  static bool get hasAlphaVantageProxyUrl =>
      alphaVantageProxyUrl.trim().isNotEmpty;
}
