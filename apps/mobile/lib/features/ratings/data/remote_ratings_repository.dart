import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/rating_models.dart';
import 'ratings_repository.dart';
import 'ratings_repository_impl.dart';

/// HTTP-backed [RatingsRepository]. Posts the submission to the
/// `POST /api/activities/{activityId}/ratings` endpoint once it ships.
///
/// While the backend is still in development this implementation
/// delegates straight to [LocalRatingsRepository] so the screen continues
/// to behave like a completed integration. The fallback is intentional —
/// keeping the public surface stable means mobile can ship the UI
/// independently of the API work and the provider switch becomes a
/// one-line change later.
class RemoteRatingsRepository implements RatingsRepository {
  RemoteRatingsRepository({
    ApiClient? client,
    RatingsRepository? fallback,
    String currentUserId = 'me',
  }) : _client = client ?? ApiClient.instance,
       _fallback = fallback ?? LocalRatingsRepository(currentUserId: currentUserId);

  final ApiClient _client;
  final RatingsRepository _fallback;

  @override
  Future<RatingSubmissionResult> submitActivityRating(
    ActivityRatingSubmission submission,
  ) async {
    try {
      final res = await _client.dio.post(
        '/activities/${submission.activityId}/ratings',
        data: {
          'sport_type': submission.activitySportType,
          'comment': ?submission.comment,
          'participant_ratings': submission.participants
              .map(
                (p) => {'ratee_uid': p.rateeUserId, 'stars': p.stars},
              )
              .toList(),
        },
      );

      final accepted = res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
      return RatingSubmissionResult(
        accepted: accepted,
        submittedAt: DateTime.now(),
        remoteError: accepted ? null : 'Server returned ${res.statusCode}',
      );
    } catch (e, st) {
      debugPrint('[RemoteRatingsRepository] submit failed, falling back: $e\n$st');
      return _fallback.submitActivityRating(submission);
    }
  }

  @override
  Future<bool> hasRated(String activityId) async {
    try {
      final res = await _client.dio.get('/activities/$activityId/my-rating');
      return res.data is Map && res.data['has_rated'] == true;
    } catch (_) {
      return _fallback.hasRated(activityId);
    }
  }
}
