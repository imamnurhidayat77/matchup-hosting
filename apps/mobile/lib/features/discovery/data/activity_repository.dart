import '../../activities/domain/activity_participant.dart';
import '../domain/activity_model.dart';
import '../domain/discovery_filter.dart';

/// Read/write contract for activity data. Both [LocalActivityRepository]
/// (current static-data fallback) and [RemoteActivityRepository] (calls
/// the MatchUp backend via [ApiClient]) implement this interface, so screens
/// can swap implementations at the provider layer without changes.
abstract class ActivityRepository {
  /// Discovery feed. When [filter] is non-null and non-empty, routes
  /// to `GET /api/activities?discover=1&...` for the ranked pipeline.
  /// When null or empty, falls back to the regular feed path so the
  /// "no filter" case stays cheap.
  ///
  /// Implementations may serve a short-TTL in-memory cache; pass
  /// [forceRefresh] to skip it (filter changes, manual refresh).
  Future<List<ActivityModel>> feed({
    int limit = 20,
    int offset = 0,
    DiscoveryFilter? filter,
    bool forceRefresh = false,
  });

  Future<ActivityModel?> byId(String id);

  /// Roster for a single activity, used by the Activity Participants screen.
  Future<List<ActivityParticipant>> participants(String activityId);

  Future<List<ActivityModel>> joinedByUser(String userId);

  Future<List<ActivityModel>> hostedByUser(String userId);

  Future<List<ActivityModel>> search({
    String? sport,
    String? skillLevel,
    double? maxDistanceKm,
  });

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
    String? address,
  });

  Future<void> join(String activityId);

  Future<void> leave(String activityId);

  /// Files a join request on an approval-gated activity. Throws when
  /// the activity is open-policy (call [join] instead), full, or a
  /// request is already pending. Withdrawing a pending request goes
  /// through [leave], which cancels it server-side.
  Future<void> requestJoin(String activityId);

  /// Pending join requests for an activity. Host-only on the backend;
  /// returns empty for anyone else (or offline).
  Future<List<ActivityParticipant>> joinRequests(String activityId);

  /// Host-only decision on a pending request.
  Future<void> approveJoinRequest(String activityId, String uid);

  /// Host-only decision on a pending request.
  Future<void> declineJoinRequest(String activityId, String uid);

  /// Cancels a hosted activity, notifying all participants. Used by the
  /// Manage Activity screen's host-only "Cancel Activity" action.
  Future<void> cancel(String activityId);

  /// Host-only field update (`PATCH /api/activities/:id`). Only
  /// non-null fields are sent; the backend validates + ignores the
  /// rest. Used by the edit screen.
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
  });

  /// Generic host-only status update. [status] is the wire value the
  /// backend accepts: `'open' | 'cancelled' | 'completed' | 'removed'`.
  /// Use this for "mark as completed" once the activity time has passed;
  /// [cancel] stays as a convenience wrapper for `'cancelled'`.
  Future<void> updateStatus(String activityId, String status);

  Future<List<ActivityModel>> pastByUser(String userId);

  /// Outgoing pending join requests (`GET /api/activities/join-requests/me`),
  /// mapped to lightweight [ActivityModel]s with `joinRequestStatus:
  /// 'pending' for the My Games "Pending" tab.
  Future<List<ActivityModel>> pendingRequests();

  /// Persists a check-in (`POST /api/activities/:id/check-in`).
  /// Throws on failure so the check-in screen can show an error and
  /// revert to the not-checked-in state.
  Future<void> checkIn({
    required String activityId,
    double? latitude,
    double? longitude,
  });

  /// Whether the viewer already checked in
  /// (`GET /api/activities/:id/check-in/me`).
  Future<bool> isCheckedIn(String activityId);
}
