import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last visited route so the app can resume from where the user
/// left off after being minimized or killed by the OS.
///
/// Auth routes are never persisted (there is no session to resume with —
/// the router gates those to /welcome anyway, and splash clears the
/// store on logout). The get-to-know onboarding steps ARE persisted so a
/// restart mid-onboarding resumes the flow instead of dropping the user
/// into Discovery with an unfinished profile — each step saves its
/// answer to the backend before advancing, so nothing is lost.
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
    '/reset-link-sent',
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
