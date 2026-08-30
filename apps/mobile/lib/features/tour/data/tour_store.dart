/// Persists whether a given tour (identified by [tourId]) has already been
/// shown to the user, so it only plays once per install.
abstract class TourStore {
  Future<bool> hasSeen(String tourId);
  Future<void> markSeen(String tourId);

  /// Clears the seen flag so the tour can be replayed (e.g. Profile →
  /// "Replay tour").
  Future<void> reset(String tourId);
}
