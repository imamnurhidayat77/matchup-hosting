/// Whether a user is currently online. The backend's presence service
/// stores the latest state per uid at `presence/{uid}` in the Realtime
/// Database.
enum PresenceState {
  online,
  offline;

  /// Wire-format value the backend expects (`'online' | 'offline'`).
  String get wireValue => name;

  /// Inverse of [wireValue]. Returns `null` for unknown / null input so
  /// callers can fall back to a sensible default (e.g. "treat as offline").
  static PresenceState? fromWire(String? value) {
    switch (value) {
      case 'online':
        return PresenceState.online;
      case 'offline':
        return PresenceState.offline;
      default:
        return null;
    }
  }
}

/// A snapshot of one user's presence state as returned by the backend.
class PresenceRecord {
  const PresenceRecord({required this.uid, required this.state});

  final String uid;
  final PresenceState state;
}
