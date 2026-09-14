import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/rating_models.dart';
import 'ratings_repository.dart';
import 'ratings_repository_impl.dart';

/// HTTP-backed [RatingsRepository]. Posts the submission to the
/// `POST /api/activities/{activityId}/ratings` endpoint using the
/// backend's camelCase wire shape (`sportType`, `comment`,
/// `participantRatings: [{rateeUid, stars}]`). Submissions are upserts
/// server-side, so re-rating within the edit window just overwrites.
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
          'sportType': submission.activitySportType,
          'comment': ?submission.comment,
          'participantRatings': submission.participants
              .map(
                (p) => {'rateeUid': p.rateeUserId, 'stars': p.stars},
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
      // Enveloped as `{ok, data: {hasRated}}`.
      final data = apiDataMap(res.data);
      return data?['hasRated'] == true;
    } catch (_) {
      return _fallback.hasRated(activityId);
    }
  }
}
