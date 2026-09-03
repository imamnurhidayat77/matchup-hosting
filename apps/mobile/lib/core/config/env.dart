import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads runtime configuration from `.env` (or `.env.example` during
/// local development). Values are read once at startup.
class Env {
  static String get apiBaseUrl =>
      dotenv.maybeGet('API_BASE_URL') ?? 'http://localhost:4000';

  static String get appEnv => dotenv.maybeGet('APP_ENV') ?? 'local';

  /// Firebase Web API Key — used by the Firebase REST Auth API.
  /// Get this from Firebase Console → Project Settings → General → Web API Key.
  static String get firebaseWebApiKey =>
      dotenv.maybeGet('FIREBASE_WEB_API_KEY') ?? '';

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
