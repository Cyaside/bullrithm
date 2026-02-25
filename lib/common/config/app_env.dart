import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  AppEnv._();

  static const _alphaVantageApiKeyName = 'ALPHA_VANTAGE_API_KEY';

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String? get alphaVantageApiKey {
    String? value;
    try {
      value = dotenv.env[_alphaVantageApiKeyName]?.trim();
    } catch (_) {
      return null;
    }
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  static bool get hasAlphaVantageApiKey => alphaVantageApiKey != null;
}
