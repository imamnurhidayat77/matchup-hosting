import '../domain/rating_models.dart';

/// Read/write contract for the post-activity rating system.
///
/// Implementations:
///  * [LocalRatingsRepository] — in-memory fallback used while the API
///    endpoint is not yet exposed; persists submissions across the session.
///  * [RemoteRatingsRepository] — POSTs to `/api/activities/{id}/ratings`
///    once the backend ships.
///
/// Both are wired through [ratingsRepositoryProvider] in
/// `core/providers/repository_providers.dart` and selected via the master
/// `useRemoteApiProvider`.
abstract class RatingsRepository {
  /// Records a single submission for a completed activity. Returns the
  /// timestamp the rating was accepted (local clock in local mode, server
  /// clock in remote mode) and an error string if the call failed.
  ///
  /// Each call replaces any earlier submission by the same rater for the
  /// same activity — clients may call this multiple times during the
  /// 7-day edit window without leaking duplicates.
  Future<RatingSubmissionResult> submitActivityRating(
    ActivityRatingSubmission submission,
  );

  /// Whether the current user has already rated a given activity. Used by
  /// past-activity entry points to decide between "Rate now" and "Edit".
  Future<bool> hasRated(String activityId);
}
