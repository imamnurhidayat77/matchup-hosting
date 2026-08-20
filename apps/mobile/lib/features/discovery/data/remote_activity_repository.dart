import '../../../core/network/api_client.dart';
import '../domain/activity_model.dart';
import 'activity_repository.dart';
import 'dummy_activity_repository.dart';

/// HTTP-backed [ActivityRepository] for the live MatchUp API. All endpoints
/// are stubbed at `/api/v1/activities/...` — replace the path constants and
/// JSON parsing once the backend ships. Until then, this implementation
/// delegates to [DummyActivityRepository] so the app keeps working.
class RemoteActivityRepository implements ActivityRepository {
  RemoteActivityRepository({ApiClient? client, ActivityRepository? fallback})
    : _client = client ?? ApiClient.instance,
      _fallback = fallback ?? DummyActivityRepository();

  final ApiClient _client;
  final ActivityRepository _fallback;

  static const _base = '/api/v1/activities';

  @override
  Future<List<ActivityModel>> feed({int limit = 20, int offset = 0}) async {
    try {
      final res = await _client.dio.get(
        _base,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return _parseList(res.data as List);
    } catch (_) {
      return _fallback.feed(limit: limit, offset: offset);
    }
  }

  @override
  Future<ActivityModel?> byId(String id) async {
    try {
      final res = await _client.dio.get('$_base/$id');
      return _parse(res.data as Map<String, dynamic>);
    } catch (_) {
      return _fallback.byId(id);
    }
  }

  @override
  Future<List<ActivityModel>> joinedByUser(String userId) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/users/$userId/joined-activities',
      );
      return _parseList(res.data as List);
    } catch (_) {
      return _fallback.joinedByUser(userId);
    }
  }

  @override
  Future<List<ActivityModel>> hostedByUser(String userId) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/users/$userId/hosted-activities',
      );
      return _parseList(res.data as List);
    } catch (_) {
      return _fallback.hostedByUser(userId);
    }
  }

  @override
  Future<List<ActivityModel>> search({
    String? sport,
    String? skillLevel,
    double? maxDistanceKm,
  }) async {
    try {
      final res = await _client.dio.get(
        '$_base/search',
        queryParameters: {
          'sport': ?sport,
          'skill': ?skillLevel,
          'max_km': ?maxDistanceKm,
        },
      );
      return _parseList(res.data as List);
    } catch (_) {
      return _fallback.search(
        sport: sport,
        skillLevel: skillLevel,
        maxDistanceKm: maxDistanceKm,
      );
    }
  }

  @override
  Future<ActivityModel> create({
    required String title,
    required String sportType,
    required String location,
    required DateTime dateTime,
    required int maxParticipants,
    required String skillLevel,
    required double fee,
  }) async {
    try {
      final res = await _client.dio.post(
        _base,
        data: {
          'title': title,
          'sport_type': sportType,
          'location': location,
          'date_time': dateTime.toIso8601String(),
          'max_participants': maxParticipants,
          'skill_level': skillLevel,
          'fee': fee,
        },
      );
      return _parse(res.data as Map<String, dynamic>)!;
    } catch (_) {
      return _fallback.create(
        title: title,
        sportType: sportType,
        location: location,
        dateTime: dateTime,
        maxParticipants: maxParticipants,
        skillLevel: skillLevel,
        fee: fee,
      );
    }
  }

  @override
  Future<void> join(String activityId) async {
    try {
      await _client.dio.post('$_base/$activityId/join');
    } catch (_) {
      await _fallback.join(activityId);
    }
  }

  @override
  Future<void> leave(String activityId) async {
    try {
      await _client.dio.post('$_base/$activityId/leave');
    } catch (_) {
      await _fallback.leave(activityId);
    }
  }

  @override
  Future<List<ActivityModel>> pastByUser(String userId) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/users/$userId/past-activities',
      );
      return _parseList(res.data as List);
    } catch (_) {
      return _fallback.pastByUser(userId);
    }
  }

  ActivityModel? _parse(Map<String, dynamic>? json) {
    if (json == null) return null;
    return ActivityModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      sportType: json['sport_type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      dateTime:
          DateTime.tryParse(json['date_time'] as String? ?? '') ??
          DateTime.now(),
      skillLevel: json['skill_level'] as String? ?? 'All',
      capacity: (json['capacity'] as num?)?.toInt() ?? 1,
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      hostName: json['host_name'] as String? ?? '',
      coverImageUrl: json['cover_image_url'] as String?,
      status: ActivityStatus.available,
    );
  }

  List<ActivityModel> _parseList(List<dynamic> data) => data
      .map((e) => _parse(e as Map<String, dynamic>))
      .whereType<ActivityModel>()
      .toList();
}
