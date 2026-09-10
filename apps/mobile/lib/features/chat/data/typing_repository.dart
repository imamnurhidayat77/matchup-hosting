/// Read/write contract for "X is typing" indicators in activity chat.
///
/// Both [LocalTypingRepository] (in-memory, used while the backend is
/// in development) and [RemoteTypingRepository] (calls
/// `POST /api/typing` and `GET /api/typing/:activityId/:uid`) implement
/// this interface, so the chat screen can swap implementations at the
/// provider layer.
abstract class TypingRepository {
  /// Sets the current user's typing state for an activity. Idempotent
  /// — calling `setTyping(true)` twice in a row is safe; switching
  /// from `true` to `false` (and vice versa) overwrites the stored
  /// state.
  Future<void> setTyping({
    required String activityId,
    required bool isTyping,
  });

  /// Fetches a specific user's typing state for an activity. Returns
  /// `null` if the user has never reported a state (treat as "not
  /// typing" for UX).
  Future<bool?> isTyping({
    required String activityId,
    required String uid,
  });

  /// Watches a list of uids and emits the subset that's currently
  /// typing in [activityId]. Polls `GET /api/typing/:activityId/:uid`
  /// for each on a 2-second cadence — fast enough that a typing
  /// indicator feels live without drowning the network.
  Stream<Set<String>> watchTyping({
    required String activityId,
    required List<String> uids,
  });
}
