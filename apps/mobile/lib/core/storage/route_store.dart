import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last visited route so the app can resume from where the user
/// left off after being minimized or killed by the OS.
///
/// Only routes inside the authenticated shell are saved — auth/onboarding
/// routes are never persisted (there is nothing to "resume" there).
class RouteStore {
  RouteStore._();
  static final RouteStore instance = RouteStore._();

  static const _key = 'last_route';

  /// Paths that must never be stored as a resume point.
  static const _excluded = {
    '/splash',
    '/onboarding',
    '/welcome',
    '/login',
    '/register',
    '/forgot-password',
    '/otp-verification',
    '/new-password',
    '/get-to-know-1',
    '/get-to-know-2',
    '/get-to-know-3',
  };

  Future<void> save(String location) async {
    if (_excluded.any((p) => location.startsWith(p))) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, location);
  }

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
