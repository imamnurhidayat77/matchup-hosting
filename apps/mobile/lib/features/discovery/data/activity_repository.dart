import '../../activities/domain/activity_participant.dart';
import '../domain/activity_model.dart';

/// Read/write contract for activity data. Both [DummyActivityRepository]
/// (current static-data fallback) and [RemoteActivityRepository] (calls
/// the MatchUp backend via [ApiClient]) implement this interface, so screens
/// can swap implementations at the provider layer without changes.
abstract class ActivityRepository {
  Future<List<ActivityModel>> feed({int limit = 20, int offset = 0});

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
    required String location,
    required DateTime dateTime,
    required int maxParticipants,
    required String skillLevel,
    required double fee,
    int durationMinutes = 120,
  });

  Future<void> join(String activityId);

  Future<void> leave(String activityId);

  /// Cancels a hosted activity, notifying all participants. Used by the
  /// Manage Activity screen's host-only "Cancel Activity" action.
  Future<void> cancel(String activityId);

  Future<List<ActivityModel>> pastByUser(String userId);
}
