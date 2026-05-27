import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get authBaseUrl => _requireEnv('API_AUTH_BASE_URL');
  static String get conductorBaseUrl => _requireEnv('API_CONDUCTOR_BASE_URL');
  static String get busBaseUrl => _requireEnv('API_BUS_BASE_URL');

  static String _requireEnv(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception('Environment variable "$key" is not configured.');
    }
    return value;
  }
}
