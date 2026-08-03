import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads runtime configuration from `.env` (or `.env.example` during
/// local development). Values are read once at startup.
class Env {
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'http://localhost:4000';

  static String get appEnv => dotenv.maybeGet('APP_ENV') ?? 'local';

  static Future<void> load() async {
    // Try real `.env` first, fall back to the example for boilerplate runs.
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      await dotenv.load(fileName: '.env.example');
    }
  }
}