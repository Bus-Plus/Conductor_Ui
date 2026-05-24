import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static const String _envFileName = '.env';

  /// Loads app configuration and environment variables.
  ///
  /// This should be called from `main()` before any other code that
  /// depends on environment variables.
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: _envFileName);
  }

  static String requireEnv(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception('Environment variable "$key" is not configured. '
          'Make sure $_envFileName exists and contains $key.');
    }
    return value;
  }

  static bool hasEnv(String key) {
    final value = dotenv.env[key];
    return value != null && value.isNotEmpty;
  }

  static String get environment => dotenv.env['APP_ENV']?.trim() ?? 'production';
}
