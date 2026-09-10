import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../activities/domain/activity_model.dart';
import '../domain/activity_model.dart';
import 'public_activity_repository.dart';

/// Offline-only public teasers. Returns an empty list — the public
/// teasers only ever come from the live backend. The Welcome / landing
/// screen renders an empty state when this fallback is reached.
class LocalPublicActivityRepository implements PublicActivityRepository {
  @override
  Future<List<ActivityModel>> teasers({int limit = 10}) async {
    return const <ActivityModel>[];
  }
}

/// HTTP-backed [PublicActivityRepository] for the live MatchUp API.
///
/// Hits `GET /api/public/activities?limit=N` — the only endpoint in the
/// MatchUp API that doesn't require a Bearer token. Falls back to
/// [LocalPublicActivityRepository] on any network failure so the
/// landing / onboarding flow always renders.
class RemotePublicActivityRepository implements PublicActivityRepository {
  RemotePublicActivityRepository({
    ApiClient? client,
    PublicActivityRepository? fallback,
  })  : _client = client ?? ApiClient.instance,
        _fallback = fallback ?? LocalPublicActivityRepository();

  final ApiClient _client;
  final PublicActivityRepository _fallback;

  @override
  Future<List<ActivityModel>> teasers({int limit = 10}) async {
    try {
      final res = await _client.dio.get(
        '/public/activities',
        queryParameters: {'limit': limit},
      );
      final data = res.data;
      if (data is! List) return _fallback.teasers(limit: limit);
      return data
          .whereType<Map<String, dynamic>>()
          .map(ActivityModel.fromJson)
          .whereType<ActivityModel>()
          .toList();
    } catch (e, st) {
      debugPrint('[RemotePublicActivityRepository] $e\n$st');
      return _fallback.teasers(limit: limit);
    }
  }
}
