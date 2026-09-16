import 'local_storage.dart';

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
    '/suspended',
    '/onboarding',
    '/welcome',
    '/login',
    '/register',
    '/forgot-password',
    '/reset-link-sent',
    '/get-to-know-1',
    '/get-to-know-2',
    '/get-to-know-3',
  };

  /// Tab roots that are safe to resume into.
  static const _tabRoots = {
    '/discovery',
    '/activities',
    '/create',
    '/messages',
    '/profile',
  };

  static bool _isAllowed(String location) {
    if (_tabRoots.contains(location)) return true;
    // Activity detail family: /activity/:id and its sub-routes.
    if (location == '/activity' || location.startsWith('/activity/')) {
      return true;
    }
    return false;
  }

  Future<void> save(String location) async {
    if (_excluded.any((p) => location == p || location.startsWith('$p/'))) {
      return;
    }
    if (!_isAllowed(location)) return;
    final storage = await LocalStorage.create();
    await storage.setString(_key, location);
  }

  Future<String?> read() async {
    final storage = await LocalStorage.create();
    return storage.getString(_key);
  }

  Future<void> clear() async {
    final storage = await LocalStorage.create();
    await storage.remove(_key);
  }
}
