import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads runtime configuration from `.env` (or `.env.example` during
/// local development). Values are read once at startup.
class Env {
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'http://localhost:4000';

  static String get appEnv => dotenv.maybeGet('APP_ENV') ?? 'local';

  /// Toggle for the data layer: `true` hits the live backend, `false` keeps
  /// the in-memory dummy repository. Defaults to `false` until the API is
  /// ready; flip to `true` via env or provider override once endpoints ship.
  static bool get useRemoteApi =>
      (dotenv.maybeGet('USE_REMOTE_API') ?? 'false').toLowerCase() == 'true';

  static Future<void> load() async {
    // Try real `.env` first, fall back to the example for boilerplate runs.
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      await dotenv.load(fileName: '.env.example');
    }
  }
}