import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../core/utils/geo.dart' show haversineKm;
import '../../activities/domain/activity_participant.dart';
import '../domain/activity_model.dart';
import '../domain/discovery_filter.dart';
import 'activity_repository.dart';
import 'activity_repository_impl.dart';

/// Normalises a mobile-side skill label to the backend enum
/// (`beginner` | `intermediate` | `advanced` | `any`). The backend
/// rejects anything else with INVALID_INPUT.
String _normaliseSkill(String skillLevel) {
  final lower = skillLevel.toLowerCase();
  if (lower == 'all' || lower == 'all level') return 'any';
  return lower;
}

/// HTTP-backed [ActivityRepository] for the live MatchUp API.
///
/// Hits the real api-server routes under `/api/activities` and unwraps
/// the `{ok, data}` envelope on every response. The backend has no
/// dedicated joined/hosted/past/search routes, so those reads are
/// derived from the `GET /activities` feed via the viewer context
/// (`isParticipant` / `isHost`) the server attaches per activity.
class RemoteActivityRepository implements ActivityRepository {
  RemoteActivityRepository({ApiClient? client, ActivityRepository? fallback})
    : _client = client ?? ApiClient.instance,
      _fallback = fallback ?? LocalActivityRepository();

  final ApiClient _client;
  final ActivityRepository _fallback;

  static const _base = '/activities';

  @override
  Future<List<ActivityModel>> feed({
    int limit = 20,
    int offset = 0,
    DiscoveryFilter? filter,
  }) async {
    debugPrint(
      '[RemoteActivityRepository.feed] filter=$filter isEmpty=${filter?.isEmpty} '
      'sportSkills=${filter?.sportSkills.length} '
      'datePreset=${filter?.datePreset} '
      'maxDistanceKm=${filter?.maxDistanceKm} limit=$limit',
    );
    if (filter != null && !filter.isEmpty) {
      try {
        final res = await _discoverFeed(filter, limit);
        debugPrint(
          '[RemoteActivityRepository.feed] discover returned '
          '${res.length} activities',
        );
        return res;
      } catch (e, st) {
        debugPrint(
          '[RemoteActivityRepository.feed] discover threw, falling back: '
          '$e\n$st',
        );
        return _fallback.feed(limit: limit, offset: offset);
      }
    }
    try {
      final res = await _client.dio.get(
        _base,
        queryParameters: {'limit': limit},
      );
      final activities = _parseList(apiDataList(res.data));
      debugPrint(
        '[RemoteActivityRepository.feed] legacy: ${res.statusCode} count=${activities.length} '
        'uri=${res.requestOptions.uri}',
      );
      return _withDistances(activities);
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.feed] $e\n$st');
      return _fallback.feed(limit: limit, offset: offset);
    }
  }

  /// `?discover=1` ranked pipeline. The backend reads each filter
  /// segment from the query string and applies sport/skill + date +
  /// geo + swipe-exclude + preference ranking. When the user hasn't
  /// granted location, the geo leg is simply skipped.
  Future<List<ActivityModel>> _discoverFeed(
    DiscoveryFilter filter,
    int limit,
  ) async {
    final params = <String, dynamic>{
      'discover': '1',
      'limit': limit,
      if (filter.includeSwiped) 'includeSwiped': 'true',
    };

    final sports = filter.sportFiltersQueryParam;
    if (sports != null) params['sportFilters'] = sports;

    final range = filter.dateRange;
    if (range.startAfter != null) params['startAfter'] = range.startAfter;
    if (range.startBefore != null) params['startBefore'] = range.startBefore;

    if (filter.maxDistanceKm != null) {
      debugPrint('[discover] requesting location for geo filter');
      final position = await LocationService.instance.getCurrentLocation();
      debugPrint('[discover] location: $position');
      if (position != null) {
        params['nearLat'] = position.latitude;
        params['nearLng'] = position.longitude;
        params['radiusKm'] = filter.maxDistanceKm;
      } else {
        debugPrint(
          '[discover] no location — sending discover without geo leg',
        );
      }
    }

    final uri = Uri(
      path: _base,
      queryParameters:
          params.map((k, v) => MapEntry(k, v.toString())),
    );
    debugPrint('[discover] request URI: $uri');
    debugPrint(
      '[discover] _discoverFeed ENTERED with filter=$filter limit=$limit',
    );

    final res = await _client.dio.get(_base, queryParameters: params);
    debugPrint(
      '[discover] response: ${res.statusCode} count=${apiDataList(res.data).length} '
      'firstRow=${apiDataList(res.data).isNotEmpty ? (apiDataList(res.data).first as Map)['sportType'] : 'n/a'}',
    );
    return _parseList(apiDataList(res.data));
  }

  /// Fills [ActivityModel.distanceKm] from the device's current position
  /// and each activity's venue coordinates (the backend has no geo
  /// queries, so the phone does the math). Best-effort: when location
  /// is unavailable or an activity carries no coordinates, its distance
  /// stays whatever the payload said (0.0 for backend rows).
  Future<List<ActivityModel>> _withDistances(
    List<ActivityModel> activities,
  ) async {
    final position = await LocationService.instance.getCurrentLocation();
    if (position == null) return activities;
    return [
      for (final a in activities)
        if (a.latitude != null && a.longitude != null)
          a.copyWith(
            distanceKm: haversineKm(
              position.latitude,
              position.longitude,
              a.latitude!,
              a.longitude!,
            ),
          )
        else
          a,
    ];
  }

  @override
  Future<ActivityModel?> byId(String id) async {
    try {
      final res = await _client.dio.get('$_base/$id');
      return _parse(apiDataMap(res.data));
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.byId] $e\n$st');
      return _fallback.byId(id);
    }
  }

  @override
  Future<List<ActivityModel>> joinedByUser(String userId) async {
    // No dedicated backend route — the feed already carries viewer
    // context (`isParticipant` / `isHost` per activity, resolved from
    // the Bearer token), so "joined" is derived client-side. Hosted
    // activities are excluded; they have their own tab.
    try {
      final all = await feed(limit: 50);
      return all
          .where((a) => a.isParticipant && !a.isHost)
          .toList();
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.joinedByUser] $e\n$st');
      return _fallback.joinedByUser(userId);
    }
  }

  @override
  Future<List<ActivityModel>> hostedByUser(String userId) async {
    try {
      final all = await feed(limit: 50);
      return all.where((a) => a.isHost).toList();
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.hostedByUser] $e\n$st');
      return _fallback.hostedByUser(userId);
    }
  }

  @override
  Future<List<ActivityModel>> search({
    String? sport,
    String? skillLevel,
    double? maxDistanceKm,
  }) async {
    // The backend list endpoint supports `sportType` + `skillLevel`
    // filters directly — there is no `/search` sub-path. `maxDistanceKm`
    // has no server-side equivalent (no geo queries yet): distances are
    // computed client-side in [_withDistances], then filtered here.
    // Without a device location every row reports 0 km and the filter
    // is a no-op rather than hiding everything.
    try {
      final res = await _client.dio.get(
        _base,
        queryParameters: {
          'limit': 50,
          if (sport != null && sport.isNotEmpty) 'sportType': sport,
          if (skillLevel != null && skillLevel.isNotEmpty)
            'skillLevel': _normaliseSkill(skillLevel),
        },
      );
      final results =
          await _withDistances(_parseList(apiDataList(res.data)));
      if (maxDistanceKm == null) return results;
      return results.where((a) => a.distanceKm <= maxDistanceKm).toList();
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.search] $e\n$st');
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
    required String description,
    required String location,
    required DateTime dateTime,
    required int maxParticipants,
    required String skillLevel,
    required double latitude,
    required double longitude,
    required String geohash,
    int durationMinutes = 120,
    String? coverImageUrl,
    String joinPolicy = 'open',
  }) async {
    try {
      final res = await _client.dio.post(
        _base,
        data: {
          'title': title,
          'sportType': sportType,
          'description': description,
          'locationName': location,
          'latitude': latitude,
          'longitude': longitude,
          'geohash': geohash,
          'startTime': dateTime.toIso8601String(),
          'endTime': dateTime
              .add(Duration(minutes: durationMinutes))
              .toIso8601String(),
          'skillLevel': _normaliseSkill(skillLevel),
          'capacity': maxParticipants,
          if (coverImageUrl != null && coverImageUrl.isNotEmpty)
            'coverImageUrl': coverImageUrl,
          'joinPolicy': joinPolicy,
        },
      );
      // Create returns `{activityId}` only — fetch the full record so
      // the caller gets viewer context (isHost etc.) like every other
      // read path.
      final createdId =
          apiDataMap(res.data)?['activityId']?.toString() ?? '';
      if (createdId.isEmpty) {
        throw const FormatException('create response missing activityId');
      }
      final created = await byId(createdId);
      if (created != null) return created;
      // The write succeeded but the follow-up read failed (transient
      // blip) — synthesise the record from the inputs rather than
      // throwing away a successful create.
      return ActivityModel(
        id: createdId,
        title: title,
        sportType: sportType,
        description: description,
        location: location,
        distanceKm: 0,
        dateTime: dateTime,
        skillLevel: skillLevel,
        capacity: maxParticipants,
        participantCount: 0,
        hostName: 'You',
        coverImageUrl: coverImageUrl,
        status: ActivityStatus.hosted,
        durationMinutes: durationMinutes,
        isHost: true,
        hostId: await _readMyUid(),
      );
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.create] $e\n$st');
      return _fallback.create(
        title: title,
        sportType: sportType,
        description: description,
        location: location,
        dateTime: dateTime,
        maxParticipants: maxParticipants,
        skillLevel: skillLevel,
        latitude: latitude,
        longitude: longitude,
        geohash: geohash,
        durationMinutes: durationMinutes,
        coverImageUrl: coverImageUrl,
        joinPolicy: joinPolicy,
      );
    }
  }

  @override
  Future<void> join(String activityId) async {
    try {
      // Backend route is `POST /api/activities/:activityId/participants`.
      // The previous `$_base/$activityId/join` returned 404 because that
      // sub-path doesn't exist on the backend.
      await _client.dio.post('$_base/$activityId/participants');
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.join] $e\n$st');
      await _fallback.join(activityId);
    }
  }

  @override
  Future<void> requestJoin(String activityId) async {
    try {
      await _client.dio.post('$_base/$activityId/join-requests');
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.requestJoin] $e\n$st');
      await _fallback.requestJoin(activityId);
    }
  }

  @override
  Future<List<ActivityParticipant>> joinRequests(String activityId) async {
    try {
      final res = await _client.dio.get('$_base/$activityId/join-requests');
      return apiDataList(res.data)
          .whereType<Map<String, dynamic>>()
          .map(_parseJoinRequest)
          .toList();
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.joinRequests] $e\n$st');
      return _fallback.joinRequests(activityId);
    }
  }

  @override
  Future<void> approveJoinRequest(String activityId, String uid) async {
    try {
      await _client.dio.post('$_base/$activityId/join-requests/$uid/approve');
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.approveJoinRequest] $e\n$st');
      await _fallback.approveJoinRequest(activityId, uid);
    }
  }

  @override
  Future<void> declineJoinRequest(String activityId, String uid) async {
    try {
      await _client.dio.post('$_base/$activityId/join-requests/$uid/decline');
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.declineJoinRequest] $e\n$st');
      await _fallback.declineJoinRequest(activityId, uid);
    }
  }

  /// Parses one join request row:
  /// `{requestId, uid, activityId, status, createdAt, profile?}`.
  /// Reuses the participant flattening so roster widgets render
  /// requesters identically to members.
  ActivityParticipant _parseJoinRequest(Map<String, dynamic> json) {
    final participant = _parseParticipant({
      'uid': json['uid'],
      'participantId': json['requestId'],
      'joinedAt': json['createdAt'],
      'profile': json['profile'],
    });
    return participant;
  }

  @override
  Future<void> leave(String activityId) async {
    try {
      // Backend route is `DELETE /api/activities/:activityId/participants/:uid`.
      // The `uid` is the *current* user (you can only remove yourself, or
      // the host can remove you — both are encoded server-side).
      final uid = await _readMyUid();
      await _client.dio.delete('$_base/$activityId/participants/$uid');
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.leave] $e\n$st');
      await _fallback.leave(activityId);
    }
  }

  @override
  Future<void> cancel(String activityId) async {
    try {
      // Cancel maps to the host-only status update endpoint
      // `PATCH /api/activities/:activityId/status` with `{ status: 'cancelled' }`.
      // The dedicated `/cancel` sub-path doesn't exist on the backend.
      await _client.dio.patch(
        '$_base/$activityId/status',
        data: {'status': 'cancelled'},
      );
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.cancel] $e\n$st');
      await _fallback.cancel(activityId);
    }
  }

  @override
  Future<void> updateStatus(String activityId, String status) async {
    try {
      await _client.dio.patch(
        '$_base/$activityId/status',
        data: {'status': status},
      );
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.updateStatus] $e\n$st');
      // Local fallback only knows 'cancelled' — for 'completed' we just
      // let the failure bubble so the UI shows a snackbar.
      if (status == 'cancelled') {
        await _fallback.cancel(activityId);
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<List<ActivityModel>> pastByUser(String userId) async {
    try {
      // No dedicated backend route — "past" means lifecycle `completed`,
      // filtered to activities the viewer hosted or joined.
      final res = await _client.dio.get(
        _base,
        queryParameters: {'status': 'completed', 'limit': 50},
      );
      return _parseList(apiDataList(res.data))
          .where((a) => a.isParticipant || a.isHost)
          .toList();
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.pastByUser] $e\n$st');
      return _fallback.pastByUser(userId);
    }
  }

  @override
  Future<List<ActivityParticipant>> participants(String activityId) async {
    try {
      final res = await _client.dio.get('$_base/$activityId/participants');
      return apiDataList(res.data)
          .whereType<Map<String, dynamic>>()
          .map(_parseParticipant)
          .toList();
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.participants] $e\n$st');
      return _fallback.participants(activityId);
    }
  }

  ActivityParticipant _parseParticipant(Map<String, dynamic> json) {
    // Backend returns each participant as:
    //   { participantId, uid, joinedAt, profile: { displayName, photoUrl, ... } | null }
    // — see backend's `ActivityParticipantWithId`. The mobile model wants
    // a flatter shape with `userId`, `name`, `avatarAsset`, `skillLevel`.
    final profile = json['profile'] as Map<String, dynamic>?;
    final joinedAtRaw = json['joinedAt'];
    // `avatarAsset` feeds `Image.asset(...)` downstream, so a remote
    // `photoUrl` must NOT be passed through as-is. When there is no
    // usable avatar, leave it null — renderers show initials instead
    // of a stock face.
    final photoUrl = profile?['photoUrl'] as String?;
    final avatarUrl = (photoUrl != null && photoUrl.isNotEmpty)
        ? photoUrl
        : null;
    final avatarAsset = (photoUrl != null &&
            !photoUrl.startsWith('http') &&
            photoUrl.isNotEmpty)
        ? photoUrl
        : json['avatar_asset'] as String?;
    return ActivityParticipant(
      userId: json['uid']?.toString() ??
          json['userId']?.toString() ??
          json['user_id']?.toString() ??
          json['participantId']?.toString() ??
          '',
      name: profile?['displayName'] as String? ??
          json['name'] as String? ??
          '',
      avatarAsset: avatarAsset,
      avatarUrl: avatarUrl,
      skillLevel: profile?['skillLevel'] as String? ??
          json['skill_level'] as String? ??
          'All',
      joinedAt: _parseTimestamp(joinedAtRaw) ?? DateTime.now(),
      // Backend doesn't surface organiser / check-in state yet — default
      // to false so the UI renders identically. The local fallback keeps
      // the rich seed data for the offline experience.
      isOrganizer: json['is_organizer'] as bool? ?? false,
      isCheckedIn: json['is_checked_in'] as bool? ?? false,
    );
  }

  /// Coerces a Firestore Timestamp — which arrives as either an ISO string
  /// (admin SDK `Timestamp.toDate()` serialised), the `{ seconds,
  /// nanoseconds }` shape, or a Dart `DateTime` — into a [DateTime].
  DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is DateTime) return raw;
    if (raw is Map) {
      final seconds = raw['seconds'] ?? raw['_seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
      }
    }
    return null;
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

  /// Reads the current user's Firebase auth uid from secure storage. Used
  /// by the leave-participant route which requires `:uid` in the URL.
  /// Returns an empty string if no session is active — the resulting
  /// request will 401 and fall through to the local fallback.
  Future<String> _readMyUid() async {
    return (await SecureTokenStore.instance.readUserId()) ?? '';
  }
}
