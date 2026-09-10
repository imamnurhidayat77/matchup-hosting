import '../domain/presence_state.dart';

/// Read/write contract for the current user's online/offline state.
///
/// Both [LocalPresenceRepository] (in-memory, used while the backend is
/// in development) and [RemotePresenceRepository] (calls
/// `POST /api/presence` and `GET /api/presence/:uid`) implement this
/// interface, so the app-lifecycle observer can swap implementations
/// at the provider layer.
abstract class PresenceRepository {
  /// Sets the current user's presence state. Backend stores it in the
  /// Realtime Database at `presence/{uid}`; the HTTP endpoint is a thin
  /// wrapper that just forwards the write.
  Future<void> setMyState(PresenceState state);

  /// Fetches another user's current presence state. Returns `null` if
  /// the user has never reported a state (treat as "offline" for UX).
  Future<PresenceState?> getState(String uid);

  /// Watches a list of uids and emits the subset that's currently
  /// online. Polls `GET /api/presence/:uid` for each on a 30-second
  /// cadence — the backend's presence is server-side authoritative,
  /// so polling is fine; the alternative is a per-uid RTDB listener
  /// which would burn a connection per subscribed user.
  Stream<Set<String>> watchOnline(List<String> uids);
}
