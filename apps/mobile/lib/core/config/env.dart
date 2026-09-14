import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads runtime configuration from `.env` (or `.env.example` during
/// local development). Values are read once at startup.
class Env {
  static String get apiBaseUrl {
    final raw =
        dotenv.maybeGet('API_BASE_URL') ?? 'http://localhost:4000';
    return _androidEmulatorHost(raw);
  }

  /// On Android, `localhost` inside the app is the emulator/device
  /// itself — not the dev machine. Rewrite a localhost base URL to the
  /// emulator's host-loopback alias (`10.0.2.2`) so `flutter run` works
  /// out of the box on an Android emulator with zero config.
  ///
  /// Physical devices still need the machine's LAN IP in `.env`
  /// (e.g. `API_BASE_URL=http://192.168.1.5:4000`); iOS Simulator
  /// shares the Mac network so plain `localhost` is fine there.
  static String _androidEmulatorHost(String url) {
    if (kIsWeb) return url;
    if (!Platform.isAndroid) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return uri.replace(host: '10.0.2.2').toString();
    }
    return url;
  }

  static String get appEnv => dotenv.maybeGet('APP_ENV') ?? 'local';

  /// Firebase Web API Key — used by the Firebase REST Auth API.
  /// Get this from Firebase Console → Project Settings → General → Web API Key.
  static String get firebaseWebApiKey =>
      dotenv.maybeGet('FIREBASE_WEB_API_KEY') ?? '';

  /// Master switch for backend data. The app **always** talks to the
  /// backend now — the local-only mode has been removed and the
  /// in-memory dummy store was emptied. Toggling this off would
  /// result in an empty UI, so leave it as `true`.
  static bool get useRemoteApi =>
      (dotenv.maybeGet('USE_REMOTE_API') ?? 'true').toLowerCase() == 'true';

  static Future<void> load() async {
    // Try real `.env` first, fall back to the example for boilerplate runs.
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      await dotenv.load(fileName: '.env.example');
    }
  }
}
