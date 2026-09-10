import '../domain/swipe_decision.dart';
import 'swipes_repository.dart';

/// Offline-only swipes store. Reads return empty, writes are no-ops.
/// The app **always** talks to the live backend for swipes — without
/// it, the user's "I've seen this" filter has nothing to filter
/// against anyway, so an empty list is the correct behaviour.
class LocalSwipesRepository implements SwipesRepository {
  @override
  Future<void> save({
    required String activityId,
    required SwipeDecision decision,
  }) async {}

  @override
  Future<SwipeDecision?> getDecision(String activityId) async {
    return null;
  }

  @override
  Future<List<SwipeRecord>> listMyDecisions() async {
    return const <SwipeRecord>[];
  }
}
