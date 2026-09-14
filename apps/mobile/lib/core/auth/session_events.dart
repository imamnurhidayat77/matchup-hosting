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
}
