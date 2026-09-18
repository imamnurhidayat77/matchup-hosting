import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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

  /// Short-TTL in-memory feed cache. Tab switches dispose the Discover
  /// state, so without this every return trip replays HTTP +
  /// GPS behind the skeleton. See [FeedCache].
  final FeedCache<List<ActivityModel>> _feedCache = FeedCache();

  /// Detail + roster caches (same TTL policy). Detail screens mount on
  /// every card tap, and roster/chat polling re-reads them — without
  /// this each open costs 1–2 HTTP round trips. Cleared on any write
  /// (join/leave/cancel/status/requests/create) so mutations never
  /// read stale.
  final FeedCache<ActivityModel?> _byIdCache = FeedCache();
  final FeedCache<List<ActivityParticipant>> _participantsCache =
      FeedCache();

  void _invalidateDetails() {
    _byIdCache.invalidateAll();
    _participantsCache.invalidateAll();
    // The feed cache too: joinedByUser/hostedByUser (My Games tabs)
    // derive from feed(), so any write must drop it — otherwise a
    // detail-screen join succeeds server-side yet Upcoming keeps
    // serving the stale pre-join list until the TTL expires.
    _feedCache.invalidateAll();
  }

  /// True when a fresh (unexpired) cache entry exists — lets screens
  /// render instantly, then decide about a silent background refresh.
  bool isFeedFresh({DiscoveryFilter? filter, int limit = 20, int offset = 0}) =>
      _feedCache.isFresh(
        FeedCache.keyFor(filter: filter, limit: limit, offset: offset),
      );

  /// Drops cached feeds (whole map, or one filter). Called after a
  /// swipe is persisted so a just-swiped card can't be re-dealt from
  /// a stale entry within the TTL window.
  void invalidateFeed({DiscoveryFilter? filter, int limit = 20, int offset = 0}) {
    if (filter == null) {
      _feedCache.invalidateAll();
    } else {
      _feedCache.remove(
        FeedCache.keyFor(filter: filter, limit: limit, offset: offset),
      );
    }
  }

  void _storeFeed(String key, List<ActivityModel> items) {
    _feedCache.put(key, items);
  }

  @override
  Future<List<ActivityModel>> feed({
    int limit = 20,
    int offset = 0,
    DiscoveryFilter? filter,
    bool forceRefresh = false,
    // Contract with the Discovery screen: when true, network/backend
    // failures rethrow instead of falling back, so the UI can render
    // its error state. Defaults to false (legacy fail-soft behavior
    // for all existing callers).
    bool strict = false,
  }) async {
    debugPrint(
      '[RemoteActivityRepository.feed] filter=$filter isEmpty=${filter?.isEmpty} '
      'sportSkills=${filter?.sportSkills.length} '
      'datePreset=${filter?.datePreset} '
      'maxDistanceKm=${filter?.maxDistanceKm} limit=$limit',
    );
    final key = FeedCache.keyFor(filter: filter, limit: limit, offset: offset);
    if (!forceRefresh) {
      final hit = _feedCache.get(key);
      if (hit != null) {
        debugPrint('[RemoteActivityRepository.feed] cache HIT (${hit.length})');
        return hit;
      }
    }
    if (filter != null && !filter.isEmpty) {
      try {
        final res = await _discoverFeed(filter, limit);
        debugPrint(
          '[RemoteActivityRepository.feed] discover returned '
          '${res.length} activities',
        );
        _storeFeed(key, res);
        return res;
      } catch (e, st) {
        debugPrint(
          '[RemoteActivityRepository.feed] discover threw, falling back: '
          '$e\n$st',
        );
        if (strict) rethrow;
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
      final withDistances = await _withDistances(activities);
      _storeFeed(key, withDistances);
      return withDistances;
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.feed] $e\n$st');
      if (strict) rethrow;
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
      // A GPS timeout degrades to "no location" (same as a denial) —
      // the feed goes out without the geo leg instead of failing.
      Position? position;
      try {
        position = await LocationService.instance.getCurrentLocation();
      } on LocationTimeoutException {
        position = null;
      }
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
    // Same distance fill as the legacy path so distance pills render on
    // filtered feeds. Fail-soft on null location (handled inside).
    return _withDistances(_parseList(apiDataList(res.data)));
  }

  /// True when the device can provide a position for the discover geo
  /// leg ([LocationService] returns non-null within its timeout).
  /// Exposed so the UI can warn ("location unavailable — distance
  /// filter skipped") instead of silently dropping the geo leg in
  /// [_discoverFeed], whose fail-soft behavior is unchanged.
  Future<bool> hasLocationForGeo() async {
    try {
      final position = await LocationService.instance.getCurrentLocation();
      return position != null;
    } on LocationTimeoutException {
      return false;
    }
  }

  /// Fills [ActivityModel.distanceKm] from the device's current position
  /// and each activity's venue coordinates (the backend has no geo
  /// queries, so the phone does the math). Best-effort: when location
  /// is unavailable or an activity carries no coordinates, its distance
  /// stays whatever the payload said (0.0 for backend rows).
  Future<List<ActivityModel>> _withDistances(
    List<ActivityModel> activities,
  ) async {
    // GPS timeout degrades to "no location" — distances stay as the
    // payload said instead of failing the whole feed.
    Position? position;
    try {
      position = await LocationService.instance.getCurrentLocation();
    } on LocationTimeoutException {
      return activities;
    }
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
    final hit = _byIdCache.get(id);
    if (hit != null) return hit;
    // Nulls are not cached: a missing activity may appear later, and
    // caching null would hide it for the whole TTL window.
    try {
      final res = await _client.dio.get('$_base/$id');
      final parsed = _parse(apiDataMap(res.data));
      if (parsed != null) _byIdCache.put(id, parsed);
      return parsed;
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.byId] $e\n$st');
      return _fallback.byId(id);
    }
  }

  @override
  Future<List<ActivityModel>> joinedByUser(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    // Dedicated paginated path (`GET /activities?mine=joined`) — no more
    // client-side filtering of a capped feed. Falls back to the legacy
    // feed-derivation when the backend predates `mine` support.
    // Both paths return soonest-first so Upcoming renders nearest-first.
    //
    // The viewer-flag filter below runs on the DEDICATED path too, not
    // just the fallback: a stale backend that doesn't understand `mine`
    // answers 200 with the full public feed (it happened — every fresh
    // account saw everyone else's games). Re-filtering by the viewer
    // context the server attaches per row is a no-op on a correct
    // backend and a lifesaver on an old one.
    try {
      final res = await _client.dio.get(
        _base,
        queryParameters: {'mine': 'joined', 'limit': limit, 'offset': offset},
      );
      final joined = _parseList(
        apiDataList(res.data),
      ).where((a) => a.isParticipant && !a.isHost).toList();
      return _sortSoonestFirst(joined);
    } catch (_) {
      // No dedicated backend route (legacy) — the feed already carries
      // viewer context (`isParticipant` / `isHost` per activity, resolved
      // from the Bearer token), so "joined" is derived client-side. Hosted
      // activities are excluded; they have their own tab.
      try {
        final all = await feed(limit: 50);
        final joined = all.where((a) => a.isParticipant && !a.isHost).toList();
        _sortSoonestFirst(joined);
        return joined.skip(offset).take(limit).toList();
      } catch (e, st) {
        debugPrint('[RemoteActivityRepository.joinedByUser] $e\n$st');
        return _fallback.joinedByUser(userId, limit: limit, offset: offset);
      }
    }
  }

  @override
  Future<List<ActivityModel>> hostedByUser(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    // Same soonest-first contract as [joinedByUser] — the Hosting tab
    // must read nearest-first. Viewer-flag filter applies on the
    // dedicated path too (see above: stale backends ignore `mine`).
    try {
      final res = await _client.dio.get(
        _base,
        queryParameters: {'mine': 'hosted', 'limit': limit, 'offset': offset},
      );
      final hosted =
          _parseList(apiDataList(res.data)).where((a) => a.isHost).toList();
      return _sortSoonestFirst(hosted);
    } catch (_) {
      try {
        final all = await feed(limit: 50);
        final hosted = all.where((a) => a.isHost).toList();
        _sortSoonestFirst(hosted);
        return hosted.skip(offset).take(limit).toList();
      } catch (e, st) {
        debugPrint('[RemoteActivityRepository.hostedByUser] $e\n$st');
        return _fallback.hostedByUser(userId, limit: limit, offset: offset);
      }
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
    bool isPaid = false,
    double? fee,
    String feeMode = 'fixed',
    double? totalCost,
    int? minPlayers,
    String? address,
  }) async {
    _invalidateDetails();
    try {
      final trimmedAddress = address?.trim();
      final res = await _client.dio.post(
        _base,
        data: {
          'title': title,
          'sportType': sportType,
          'description': description,
          'locationName': location,
          if (trimmedAddress != null && trimmedAddress.isNotEmpty)
            'address': trimmedAddress,
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
          'isPaid': isPaid,
          // Free activities never carry a fee (backend drops it anyway);
          // paid ones require a positive amount.
          if (isPaid && fee != null) 'fee': fee,
          if (isPaid && feeMode == 'split') 'feeMode': feeMode,
          if (isPaid && feeMode == 'split' && totalCost != null)
            'totalCost': totalCost,
          if (isPaid && feeMode == 'split' && minPlayers != null)
            'minPlayers': minPlayers,
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
        addressLine: trimmedAddress?.isNotEmpty == true ? trimmedAddress : null,
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
        isPaid: isPaid,
        fee: fee,
        feeMode: feeMode,
        totalCost: totalCost,
        minPlayers: minPlayers,
      );
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.create] $e\n$st');
      // No offline fallback: the local store always throws
      // `StateError('requires live backend')`, which would mask the
      // real cause. Rethrow so the create screen's try/catch shows
      // the actual failure with its Retry path.
      rethrow;
    }
  }

  @override
  Future<void> join(String activityId) async {
    // No local fallback: the backend owns membership state (full,
    // started, already joined), and its 409 answers carry the reason
    // the screen shows. The old fallback swallowed rejections, so a
    // failed join navigated to the joined screen as if it succeeded.
    _invalidateDetails();
    // Backend route is `POST /api/activities/:activityId/participants`.
    // The previous `$_base/$activityId/join` returned 404 because that
    // sub-path doesn't exist on the backend.
    await _client.dio.post('$_base/$activityId/participants');
  }

  @override
  Future<void> requestJoin(String activityId) async {
    // No local fallback: the backend owns join-request state (pending
    // duplicates, full, closed), and its 409/4xx answers carry the
    // reason the screen shows. Swallowing them here turned precise
    // rejections (e.g. "already pending") into mystery failures.
    _invalidateDetails();
    await _client.dio.post('$_base/$activityId/join-requests');
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
    // No local fallback (mirrors join/requestJoin): the backend owns
    // request state, so failures must surface to the caller instead of
    // silently succeeding locally.
    _invalidateDetails();
    await _client.dio.post('$_base/$activityId/join-requests/$uid/approve');
  }

  @override
  Future<void> declineJoinRequest(String activityId, String uid) async {
    // No local fallback (mirrors join/requestJoin) — see above.
    _invalidateDetails();
    await _client.dio.post('$_base/$activityId/join-requests/$uid/decline');
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
    // No local fallback (mirrors join/requestJoin): the backend owns
    // membership state, so failures must surface to the caller instead
    // of silently succeeding locally.
    _invalidateDetails();
    // Backend route is `DELETE /api/activities/:activityId/participants/:uid`.
    // The `uid` is the *current* user (you can only remove yourself, or
    // the host can remove you — both are encoded server-side).
    final uid = await _readMyUid();
    await _client.dio.delete('$_base/$activityId/participants/$uid');
  }

  @override
  Future<void> removeParticipant({
    required String activityId,
    required String uid,
  }) async {
    // No local fallback (mirrors join/leave): the backend owns
    // membership state, and its 403/404 answers carry the reason the
    // manage screen shows. Swallowing them would drop the row locally
    // while the player is still in the game server-side.
    _invalidateDetails();
    await _client.dio.delete('$_base/$activityId/participants/$uid');
  }

  @override
  Future<void> cancel(String activityId) async {
    // No local fallback (mirrors join/requestJoin) — see above.
    _invalidateDetails();
    // Cancel maps to the host-only status update endpoint
    // `PATCH /api/activities/:activityId/status` with `{ status: 'cancelled' }`.
    // The dedicated `/cancel` sub-path doesn't exist on the backend.
    await _client.dio.patch(
      '$_base/$activityId/status',
      data: {'status': 'cancelled'},
    );
  }

  @override
  Future<void> updateStatus(String activityId, String status) async {
    try {
      _invalidateDetails();
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
  Future<void> updateActivity({
    required String activityId,
    String? title,
    String? sportType,
    String? description,
    String? locationName,
    double? latitude,
    double? longitude,
    String? geohash,
    DateTime? startTime,
    DateTime? endTime,
    String? skillLevel,
    int? capacity,
    String? joinPolicy,
    bool? isPaid,
    double? fee,
  }) async {
    _invalidateDetails();
    invalidateFeed();
    final Map<String, dynamic> data = {};
    void setIfPresent(String key, Object? value) {
      if (value != null) data[key] = value;
    }

    setIfPresent('title', title);
    setIfPresent('sportType', sportType);
    setIfPresent('description', description);
    setIfPresent('locationName', locationName);
    setIfPresent('latitude', latitude);
    setIfPresent('longitude', longitude);
    setIfPresent('geohash', geohash);
    setIfPresent('startTime', startTime?.toIso8601String());
    setIfPresent('endTime', endTime?.toIso8601String());
    setIfPresent(
      'skillLevel',
      skillLevel == null ? null : _normaliseSkill(skillLevel),
    );
    setIfPresent('capacity', capacity);
    setIfPresent('joinPolicy', joinPolicy);
    setIfPresent('isPaid', isPaid);
    setIfPresent('fee', fee);
    try {
      await _client.dio.patch('$_base/$activityId', data: data);
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.updateActivity] $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> updateCover({
    required String activityId,
    required String coverImagePath,
    required String coverImageUrl,
  }) async {
    // No local fallback and no silent swallow: the activity already
    // exists at this point, so a throw lets the caller warn while
    // keeping the created game.
    _invalidateDetails();
    invalidateFeed();
    try {
      await _client.dio.patch(
        '$_base/$activityId/cover',
        data: {
          'coverImagePath': coverImagePath,
          'coverImageUrl': coverImageUrl,
        },
      );
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.updateCover] $e\n$st');
      rethrow;
    }
  }

  @override
  Future<List<ActivityModel>> pastByUser(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // No dedicated backend route — "past" means terminal lifecycles
      // (`completed`, `cancelled` AND `removed`) filtered to activities
      // the viewer hosted or joined. Cancelled/removed must be included:
      // otherwise a called-off game vanishes from every My Games tab
      // (Upcoming only lists open games). Most-recent first so history
      // reads backwards from today.
      final responses = await Future.wait([
        _client.dio.get(
          _base,
          queryParameters: {'status': 'completed', 'limit': 50},
        ),
        _client.dio.get(
          _base,
          queryParameters: {'status': 'cancelled', 'limit': 50},
        ),
        _client.dio.get(
          _base,
          queryParameters: {'status': 'removed', 'limit': 50},
        ),
      ]);
      final seen = <String>{};
      final past = <ActivityModel>[];
      for (final res in responses) {
        for (final a in _parseList(apiDataList(res.data))) {
          if (!(a.isParticipant || a.isHost)) continue;
          if (!seen.add(a.id)) continue;
          past.add(a);
        }
      }
      _sortRecentFirst(past);
      return past.skip(offset).take(limit).toList();
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.pastByUser] $e\n$st');
      return _fallback.pastByUser(userId, limit: limit, offset: offset);
    }
  }

  @override
  Future<List<ActivityModel>> pendingRequests({int limit = 20, int offset = 0}) async {
    try {
      final res = await _client.dio.get('$_base/join-requests/me');
      final all = [
        for (final e in apiDataList(res.data))
          if (e is Map<String, dynamic>) _parsePending(e),
      ];
      // Pending lists are tiny (few requests per user) — soonest-first,
      // then slice in memory.
      _sortSoonestFirst(all);
      if (offset >= all.length) return const [];
      return all.skip(offset).take(limit).toList();
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.pendingRequests] $e\n$st');
      return _fallback.pendingRequests(limit: limit, offset: offset);
    }
  }

  /// Maps a backend pending-request view
  /// (`{activityId, title, sportType, locationName, startTime}`) to a
  /// lightweight activity for the Pending tab. Missing fields degrade
  /// to blanks — the row still renders and taps through to the detail
  /// screen, which loads the full record.
  ActivityModel _parsePending(Map<String, dynamic> json) {
    DateTime start;
    try {
      start = DateTime.parse(json['startTime'] as String);
    } catch (_) {
      // Corrupt/unparseable date: park the row behind every real game
      // with a far-future sentinel so soonest-first lists sort it last
      // (falling back to `now` wrongly floated it to the top).
      start = DateTime(2100);
    }
    return ActivityModel(
      id: json['activityId']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      sportType: json['sportType'] as String? ?? '',
      description: '',
      location: json['locationName'] as String? ?? '',
      distanceKm: 0,
      dateTime: start,
      skillLevel: '',
      capacity: 0,
      participantCount: 0,
      hostName: '',
      coverImageUrl: json['coverImageUrl'] as String?,
      isPaid: json['isPaid'] as bool? ?? false,
      fee: (json['fee'] as num?)?.toDouble(),
      joinRequestStatus: 'pending',
    );
  }

  @override
  Future<void> checkIn({
    required String activityId,
    double? latitude,
    double? longitude,
  }) async {
    // No local fallback: the backend owns attendance state, and its
    // 4xx answers carry the reason the screen shows. Swallowing them
    // here would turn precise rejections into mystery failures.
    // Follows the requestJoin/updateActivity pattern (throw on failure).
    final Map<String, dynamic> data = {};
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    await _client.dio.post('$_base/$activityId/check-in', data: data);
  }

  @override
  Future<bool> isCheckedIn(String activityId) async {
    try {
      final res = await _client.dio.get('$_base/$activityId/check-in/me');
      final map = apiDataMap(res.data);
      if (map == null) return false;
      final checkedIn = map['checkedIn'];
      if (checkedIn is bool) return checkedIn;
      // Be lenient: a raw timestamp payload also means checked in.
      if (map['checkedInAt'] is num) return true;
      return false;
    } catch (e, st) {
      debugPrint('[RemoteActivityRepository.isCheckedIn] $e\n$st');
      return false;
    }
  }

  @override
  Future<List<ActivityParticipant>> participants(String activityId) async {
    final hit = _participantsCache.get(activityId);
    if (hit != null) return hit;
    try {
      final res = await _client.dio.get('$_base/$activityId/participants');
      final parsed = apiDataList(res.data)
          .whereType<Map<String, dynamic>>()
          .map(_parseParticipant)
          .toList();
      _participantsCache.put(activityId, parsed);
      return parsed;
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
      isOrganizer: json['isOrganizer'] as bool? ??
          json['is_organizer'] as bool? ??
          false,
      isCheckedIn: json['isCheckedIn'] as bool? ??
          json['is_checked_in'] as bool? ??
          false,
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

/// Soonest event first (My Games Upcoming / Hosting / Pending contract).
/// Sorts in place and returns the same list for chaining.
List<ActivityModel> _sortSoonestFirst(List<ActivityModel> items) {
  items.sort((a, b) => a.dateTime.compareTo(b.dateTime));
  return items;
}

/// Most-recent first (My Games Past contract).
List<ActivityModel> _sortRecentFirst(List<ActivityModel> items) {
  items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return items;
}

/// Short-TTL in-memory feed cache, extracted as its own class so the
/// TTL/eviction logic is unit-testable without HTTP or GPS.
///
/// Keys cover the full filter ([keyFor]) so filter changes and
/// "Start over" always miss. The clock is injectable for tests.
class FeedCache<T> {
  FeedCache({
    DateTime Function()? clock,
    this.ttl = const Duration(seconds: 60),
    this.maxEntries = 20,
  }) : _clock = clock ?? DateTime.now;

  /// Cache key — full filter identity plus paging. Built from stable
  /// filter fields (never `filter.hashCode`, which is unstable across
  /// restarts and churns the cache on every launch).
  static String keyFor({
    required DiscoveryFilter? filter,
    required int limit,
    required int offset,
  }) {
    // Null (bare legacy-feed callers) must not collide with an empty
    // but non-null filter — both fetch the same rows, but the legacy
    // `filter.hashCode` key distinguished them, so keep that split.
    if (filter == null) return 'nofilter|$limit:$offset';
    final sports = filter.sportFiltersQueryParam ?? '';
    final preset = filter.datePreset.name;
    final after = filter.startAfter?.toIso8601String() ?? '';
    final before = filter.startBefore?.toIso8601String() ?? '';
    final dist = filter.maxDistanceKm?.toString() ?? '';
    final swiped = filter.includeSwiped;
    return '$sports|$preset|$after|$before|$dist|$swiped|$limit:$offset';
  }

  final Duration ttl;
  final int maxEntries;
  final DateTime Function() _clock;
  final Map<String, _FeedCacheEntry<T>> _entries = {};

  T? get(String key) {
    final hit = _entries[key];
    if (hit == null) return null;
    if (_clock().difference(hit.cachedAt) >= ttl) {
      _entries.remove(key);
      return null;
    }
    return hit.items;
  }

  bool isFresh(String key) => get(key) != null;

  void put(String key, T items) {
    _entries[key] = _FeedCacheEntry(items, _clock());
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void remove(String key) => _entries.remove(key);

  void invalidateAll() => _entries.clear();

  @visibleForTesting
  int get length => _entries.length;
}

/// One cached feed entry — the final list (distances already filled)
/// plus the time it was stored, for TTL checks.
class _FeedCacheEntry<T> {
  const _FeedCacheEntry(this.items, this.cachedAt);
  final T items;
  final DateTime cachedAt;
}
