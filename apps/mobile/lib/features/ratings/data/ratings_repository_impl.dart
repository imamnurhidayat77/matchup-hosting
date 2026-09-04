import 'package:flutter/foundation.dart';

import '../domain/rating_models.dart';
import 'ratings_repository.dart';

/// In-memory ratings repository used while the backend endpoint is in
/// development. All calls resolve locally and submissions are stored for the
/// lifetime of the process — they are NOT persisted between app launches.
///
/// The fake is intentionally faithful to the wire shape the remote version
/// will expect so the swap to [RemoteRatingsRepository] only changes
/// transport, not data flow.
class LocalRatingsRepository implements RatingsRepository {
  /// activityId → set of rater UIDs that already submitted (the dedup key
  /// is the activity, since each user only submits once per past activity
  /// in MVP).
  final Map<String, Set<String>> _submitted = {};

  /// Records known rater uid from the auth state — injected at construction
  /// so test overrides can pass a deterministic UID.
  LocalRatingsRepository({this._currentUserId = 'me'});

  final String _currentUserId;

  @override
  Future<RatingSubmissionResult> submitActivityRating(
    ActivityRatingSubmission submission,
  ) async {
    // Simulate small network latency so loading states are exercisable.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    _submitted
        .putIfAbsent(submission.activityId, () => <String>{})
        .add(_currentUserId);

    if (kDebugMode) {
      debugPrint(
        '[LocalRatingsRepository] stored ${submission.participants.length} '
        'rating(s) for activity=${submission.activityId}',
      );
    }

    return RatingSubmissionResult(
      accepted: true,
      submittedAt: DateTime.now(),
    );
  }

  @override
  Future<bool> hasRated(String activityId) async {
    final raters = _submitted[activityId];
    return raters != null && raters.contains(_currentUserId);
  }
}
