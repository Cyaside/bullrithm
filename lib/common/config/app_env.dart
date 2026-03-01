import 'package:shared_preferences/shared_preferences.dart';

class AppEnv {
  AppEnv._();

  static const alphaVantageApiKey = String.fromEnvironment(
    'ALPHA_VANTAGE_API_KEY',
  );
  static const alphaVantageProxyUrl = String.fromEnvironment(
    'ALPHA_VANTAGE_PROXY_URL',
  );
  static const runtimeAlphaVantageApiKeyPrefsKey =
      'runtime_alpha_vantage_api_key_v1';

  static String? _runtimeAlphaVantageApiKey;

  static bool get hasAlphaVantageApiKey => alphaVantageApiKey.trim().isNotEmpty;
  static bool get hasAlphaVantageProxyUrl =>
      alphaVantageProxyUrl.trim().isNotEmpty;

  static String? get runtimeAlphaVantageApiKey {
    final runtime = _runtimeAlphaVantageApiKey?.trim() ?? '';
    if (runtime.isEmpty) return null;
    return runtime;
  }

  static String? get effectiveAlphaVantageApiKey {
    final runtime = runtimeAlphaVantageApiKey;
    if (runtime != null && runtime.isNotEmpty) return runtime;
    final compileTime = alphaVantageApiKey.trim();
    return compileTime.isEmpty ? null : compileTime;
  }

  static bool get hasEffectiveAlphaVantageApiKey =>
      effectiveAlphaVantageApiKey != null;

  static Future<void> loadRuntimeOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(runtimeAlphaVantageApiKeyPrefsKey);
    _runtimeAlphaVantageApiKey = stored?.trim();
  }

  static Future<void> setRuntimeAlphaVantageApiKey(String? value) async {
    final normalized = value?.trim() ?? '';
    final prefs = await SharedPreferences.getInstance();

    if (normalized.isEmpty) {
      _runtimeAlphaVantageApiKey = null;
      await prefs.remove(runtimeAlphaVantageApiKeyPrefsKey);
      return;
    }

    _runtimeAlphaVantageApiKey = normalized;
    await prefs.setString(runtimeAlphaVantageApiKeyPrefsKey, normalized);
  }
}
