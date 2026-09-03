import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../activities/domain/activity_participant.dart';
import '../domain/activity_model.dart';
import 'activity_repository.dart';
import 'activity_repository_impl.dart';

/// HTTP-backed [ActivityRepository] for the live MatchUp API. All endpoints
/// are stubbed at `/api/v1/activities/...` — replace the path constants and
/// JSON parsing once the backend ships. Until then, this implementation
/// delegates to [LocalActivityRepository] so the app keeps working.
class RemoteActivityRepository implements ActivityRepository {
  RemoteActivityRepository({ApiClient? client, ActivityRepository? fallback})
    : _client = client ?? ApiClient.instance,
      _fallback = fallback ?? LocalActivityRepository();

  final ApiClient _client;
  final ActivityRepository _fallback;

  static const _base = '/activities';

  @override
  Future<List<ActivityModel>> feed({int limit = 20, int offset = 0}) async {
    try {
      final res = await _client.dio.get(
        _base,
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return _parseList(res.data as List);
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
      return _fallback.feed(limit: limit, offset: offset);
    }
  }

  @override
  Future<ActivityModel?> byId(String id) async {
    try {
      final res = await _client.dio.get('$_base/$id');
      return _parse(res.data as Map<String, dynamic>);
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
      return _fallback.byId(id);
    }
  }

  @override
  Future<List<ActivityModel>> joinedByUser(String userId) async {
    try {
      final res = await _client.dio.get('/users/$userId/joined-activities');
      return _parseList(res.data as List);
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
      return _fallback.joinedByUser(userId);
    }
  }

  @override
  Future<List<ActivityModel>> hostedByUser(String userId) async {
    try {
      final res = await _client.dio.get('/users/$userId/hosted-activities');
      return _parseList(res.data as List);
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
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
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
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
    int durationMinutes = 120,
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
          'duration_minutes': durationMinutes,
        },
      );
      return _parse(res.data as Map<String, dynamic>)!;
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
      return _fallback.create(
        title: title,
        sportType: sportType,
        location: location,
        dateTime: dateTime,
        maxParticipants: maxParticipants,
        skillLevel: skillLevel,
        fee: fee,
        durationMinutes: durationMinutes,
      );
    }
  }

  @override
  Future<void> join(String activityId) async {
    try {
      await _client.dio.post('$_base/$activityId/join');
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
      await _fallback.join(activityId);
    }
  }

  @override
  Future<void> leave(String activityId) async {
    try {
      await _client.dio.post('$_base/$activityId/leave');
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
      await _fallback.leave(activityId);
    }
  }

  @override
  Future<void> cancel(String activityId) async {
    try {
      await _client.dio.post('$_base/$activityId/cancel');
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
      await _fallback.cancel(activityId);
    }
  }

  @override
  Future<List<ActivityModel>> pastByUser(String userId) async {
    try {
      final res = await _client.dio.get('/users/$userId/past-activities');
      return _parseList(res.data as List);
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
      return _fallback.pastByUser(userId);
    }
  }

  @override
  Future<List<ActivityParticipant>> participants(String activityId) async {
    try {
      final res = await _client.dio.get('$_base/$activityId/participants');
      return (res.data as List)
          .map((e) => _parseParticipant(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository] $e\n$st');
      return _fallback.participants(activityId);
    }
  }

  ActivityParticipant _parseParticipant(Map<String, dynamic> json) {
    return ActivityParticipant(
      userId: json['user_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      avatarAsset: json['avatar_asset'] as String? ?? 'avatar_1.png',
      skillLevel: json['skill_level'] as String? ?? 'All',
      joinedAt:
          DateTime.tryParse(json['joined_at'] as String? ?? '') ??
          DateTime.now(),
      isOrganizer: json['is_organizer'] as bool? ?? false,
      isCheckedIn: json['is_checked_in'] as bool? ?? false,
    );
  }

  /// Delegates to [ActivityModel.fromJson] — the single canonical parsing
  /// path for API responses. Keeping the indirection here means callers
  /// inside this file don't need to change if the model factory is renamed.
  ActivityModel? _parse(Map<String, dynamic>? json) {
    if (json == null) return null;
    return ActivityModel.fromJson(json);
  }

  List<ActivityModel> _parseList(List<dynamic> data) => data
      .map((e) => _parse(e as Map<String, dynamic>))
      .whereType<ActivityModel>()
      .toList();
}
