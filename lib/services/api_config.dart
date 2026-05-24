import 'package:bus_tracking_conductor/services/app_config.dart';

class ApiConfig {
  static String get authBaseUrl => AppConfig.requireEnv('API_AUTH_BASE_URL');
  static String get conductorBaseUrl => AppConfig.requireEnv('API_CONDUCTOR_BASE_URL');
  static String get busBaseUrl => AppConfig.requireEnv('API_BUS_BASE_URL');
}
