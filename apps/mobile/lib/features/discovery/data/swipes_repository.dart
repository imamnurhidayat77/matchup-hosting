import '../domain/swipe_decision.dart';

/// Read/write contract for the authenticated user's swipe decisions on
/// activity cards in the discovery deck.
///
/// The production app **always** uses [RemoteSwipesRepository] (which
/// calls `POST /api/swipes`, `GET /api/swipes/me`, `GET
/// /api/swipes/me/:activityId`). The local implementation exists only
/// as a no-op fallback for the rare offline case.
abstract class SwipesRepository {
  /// Records (or updates) the user's decision for an activity.
  ///
  /// Backend behaviour: writing `join` also creates a notification for the
  /// activity host. Writing the same decision twice is idempotent on the
  /// server; switching `pass` → `join` or vice versa updates the existing
  /// record in a Firestore transaction.
  Future<void> save({
    required String activityId,
    required SwipeDecision decision,
  });

  /// Returns the user's current decision for [activityId], or `null` if
  /// they haven't swiped on it yet. Used by the discovery screen to skip
  /// cards the user has already acted on after a deck refresh.
  Future<SwipeDecision?> getDecision(String activityId);

  /// Lists every swipe the current user has recorded. Useful for the
  /// "you've already seen this" filter on a feed reload and for analytics.
  Future<List<SwipeRecord>> listMyDecisions();
}
