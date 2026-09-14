import 'dart:async';

/// App-wide broadcast for auth session lifecycle events.
///
/// Lets the networking layer ([ApiClient]'s auth interceptor) tell the
/// UI layer (auth state provider) that the stored session is dead
/// without creating an import cycle between the two.
class SessionEvents {
  SessionEvents._();

  static final SessionEvents instance = SessionEvents._();

  final StreamController<void> _expiredController =
      StreamController<void>.broadcast();

  /// Fires when the refresh token itself is rejected (stale, revoked,
  /// disabled user). Re-login is the only recovery — silent retry is
  /// pointless and would just burn battery on a dead session.
  Stream<void> get onSessionExpired => _expiredController.stream;

  void notifySessionExpired() {
    if (!_expiredController.isClosed) _expiredController.add(null);
  }

  final StreamController<void> _suspendedController =
      StreamController<void>.broadcast();

  /// Fires when the backend reports `ACCOUNT_SUSPENDED` (403). Unlike
  /// expiry the session stays alive — tokens are kept so the user can
  /// still file and track an appeal. The UI gates to the suspended
  /// interstitial instead of logging out.
  Stream<void> get onSuspended => _suspendedController.stream;

  void notifySuspended() {
    if (!_suspendedController.isClosed) _suspendedController.add(null);
  }
}
