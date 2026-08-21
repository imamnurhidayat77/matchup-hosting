import '../../activities/domain/activity_participant.dart';
import '../domain/activity_model.dart';
import 'activity_repository.dart';

/// In-memory activity data used while the MatchUp backend is in development.
/// All methods return deterministic seed data so screens render the same way
/// they did before the data layer was introduced. Replace by binding
/// [RemoteActivityRepository] in the provider override once endpoints ship.
class DummyActivityRepository implements ActivityRepository {
  DummyActivityRepository() {
    _all = _seed();
  }

  late final List<ActivityModel> _all;
  final Map<String, List<String>> _joinedByUser = {};
  final Map<String, List<String>> _hostedByUser = {};

  List<ActivityModel> _seed() {
    final now = DateTime.now();
    return [
      ActivityModel(
        id: '1',
        title: 'Saturday Afternoon 5v5 Basketball',
        sportType: 'Basketball',
        description:
            'Looking for intermediate players to join us for some friendly full-court 5v5 runs. We usually play 3 matches.',
        location: 'Central Park Court B',
        addressLine: 'Central Park, New York, NY',
        distanceKm: 2.4,
        dateTime: DateTime(now.year, now.month, now.day + 1, 16),
        skillLevel: 'Intermediate',
        capacity: 10,
        participantCount: 6,
        hostName: 'James Wilson',
        coverImageUrl: 'assets/images/discovery/covers/basketball_full.png',
        status: ActivityStatus.almostFull,
      ),
      ActivityModel(
        id: '2',
        title: 'Sunset Basketball 5v5',
        sportType: 'Basketball',
        description: 'Sunset run, 3 matches. Bring black and white jersey.',
        location: 'Brooklyn Public Courts',
        addressLine: 'Court #3, Prospect Park, NY',
        distanceKm: 5.1,
        dateTime: DateTime(now.year, now.month, now.day + 3, 18, 30),
        skillLevel: 'Intermediate',
        capacity: 12,
        participantCount: 8,
        hostName: 'Alex Mercer',
        coverImageUrl: 'assets/images/discovery/covers/basketball_full.png',
        status: ActivityStatus.available,
      ),
      ActivityModel(
        id: '3',
        title: 'Tennis Singles Sunday',
        sportType: 'Tennis',
        description: 'Casual singles, mixed levels welcome.',
        location: 'Auckland Domain Tennis Centre',
        addressLine: 'Domain Drive, Parnell, Auckland',
        distanceKm: 3.2,
        dateTime: DateTime(now.year, now.month, now.day + 4, 10),
        skillLevel: 'Beginner',
        capacity: 4,
        participantCount: 2,
        hostName: 'Mike Chen',
        coverImageUrl: 'assets/images/discovery/covers/tennis_5.png',
        status: ActivityStatus.available,
      ),
      ActivityModel(
        id: '4',
        title: 'Volleyball Co-ed',
        sportType: 'Volleyball',
        description: 'Indoor co-ed 6v6.',
        location: 'City Sports Centre',
        addressLine: 'Court 3, Level 2, Newmarket',
        distanceKm: 1.8,
        dateTime: DateTime(now.year, now.month, now.day + 5, 19),
        skillLevel: 'All',
        capacity: 12,
        participantCount: 12,
        hostName: 'Lisa Park',
        coverImageUrl: 'assets/images/discovery/sports/volleyball.png',
        status: ActivityStatus.full,
      ),
      ActivityModel(
        id: '5',
        title: 'Trail Run Saturday',
        sportType: 'Running',
        description: '8km trail run through the park. Casual pace.',
        location: 'Forest Trail Park',
        addressLine: 'North Entrance, Titirangi',
        distanceKm: 5.6,
        dateTime: DateTime(now.year, now.month, now.day + 6, 7),
        skillLevel: 'Intermediate',
        capacity: 8,
        participantCount: 3,
        hostName: 'Tyler Vance',
        coverImageUrl: 'assets/images/discovery/covers/basketball_3.png',
        status: ActivityStatus.available,
      ),
    ];
  }

  @override
  Future<List<ActivityModel>> feed({int limit = 20, int offset = 0}) async {
    await _delay();
    return _all.skip(offset).take(limit).toList();
  }

  @override
  Future<ActivityModel?> byId(String id) async {
    await _delay();
    try {
      return _all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ActivityModel>> joinedByUser(String userId) async {
    await _delay();
    // Default set matches the Figma My Activities mock — two upcoming
    // activities on different sports so the tab is populated on first
    // launch instead of showing a lonely single card in a sea of whitespace.
    final ids = _joinedByUser[userId] ?? const ['1', '3'];
    return ids
        .map(
          (id) => _all
              .where((a) => a.id == id)
              .cast<ActivityModel?>()
              .firstWhere((a) => a != null, orElse: () => null),
        )
        .whereType<ActivityModel>()
        .toList();
  }

  @override
  Future<List<ActivityModel>> hostedByUser(String userId) async {
    await _delay();
    final ids = _hostedByUser[userId] ?? const ['1'];
    return ids
        .map(
          (id) => _all
              .where((a) => a.id == id)
              .cast<ActivityModel?>()
              .firstWhere((a) => a != null, orElse: () => null),
        )
        .whereType<ActivityModel>()
        .toList();
  }

  @override
  Future<List<ActivityModel>> search({
    String? sport,
    String? skillLevel,
    double? maxDistanceKm,
  }) async {
    await _delay();
    return _all.where((a) {
      if (sport != null && a.sportType != sport) return false;
      if (skillLevel != null && a.skillLevel != skillLevel) return false;
      if (maxDistanceKm != null && a.distanceKm > maxDistanceKm) return false;
      return true;
    }).toList();
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
    await _delay();
    final id = '${_all.length + 1}';
    final created = ActivityModel(
      id: id,
      title: title,
      sportType: sportType,
      description: '',
      location: location,
      distanceKm: 0,
      dateTime: dateTime,
      skillLevel: skillLevel,
      capacity: maxParticipants,
      participantCount: 1,
      hostName: 'You',
      coverImageUrl: 'assets/images/discovery/covers/basketball_full.png',
      status: ActivityStatus.hosted,
      durationMinutes: durationMinutes,
    );
    _all.insert(0, created);
    return created;
  }

  @override
  Future<void> join(String activityId) async {
    await _delay();
    _joinedByUser.putIfAbsent('me', () => []).add(activityId);
  }

  @override
  Future<void> leave(String activityId) async {
    await _delay();
    _joinedByUser['me']?.remove(activityId);
  }

  @override
  Future<void> cancel(String activityId) async {
    await _delay();
    final index = _all.indexWhere((a) => a.id == activityId);
    if (index == -1) return;
    _all[index] = _all[index].copyWith(status: ActivityStatus.past);
  }

  @override
  Future<List<ActivityModel>> pastByUser(String userId) async {
    await _delay();
    return _all.take(1).toList();
  }

  @override
  Future<List<ActivityParticipant>> participants(String activityId) async {
    await _delay();
    final activity = _all
        .where((a) => a.id == activityId)
        .cast<ActivityModel?>()
        .firstWhere((a) => a != null, orElse: () => null);
    final now = DateTime.now();
    final roster = [
      ActivityParticipant(
        userId: 'host',
        name: activity?.hostName ?? 'James Wilson',
        avatarAsset: 'host_james.png',
        skillLevel: 'Advanced',
        joinedAt: now.subtract(const Duration(days: 6, hours: 3)),
        isOrganizer: true,
        isCheckedIn: true,
      ),
      ActivityParticipant(
        userId: 'u2',
        name: 'Alex Mercer',
        avatarAsset: 'avatar_alex.png',
        skillLevel: 'Intermediate',
        joinedAt: now.subtract(const Duration(days: 2, hours: 9)),
        isOrganizer: false,
        isCheckedIn: true,
      ),
      ActivityParticipant(
        userId: 'u3',
        name: 'Sarah Chen',
        avatarAsset: 'sarah_c.png',
        skillLevel: 'Intermediate',
        joinedAt: now.subtract(const Duration(days: 2, hours: 1)),
        isOrganizer: false,
      ),
      ActivityParticipant(
        userId: 'u4',
        name: 'Marcus Brodie',
        avatarAsset: 'avatar_1.png',
        skillLevel: 'Advanced',
        joinedAt: now.subtract(const Duration(days: 1, hours: 4)),
        isOrganizer: false,
      ),
      ActivityParticipant(
        userId: 'u5',
        name: 'Daniel Kim',
        avatarAsset: 'avatar_2.png',
        skillLevel: 'Beginner',
        joinedAt: now.subtract(const Duration(hours: 21)),
        isOrganizer: false,
      ),
      ActivityParticipant(
        userId: 'u6',
        name: 'Elena Rostova',
        avatarAsset: 'avatar_3.png',
        skillLevel: 'Intermediate',
        joinedAt: now.subtract(const Duration(hours: 6, minutes: 40)),
        isOrganizer: false,
      ),
    ];
    final capacity = activity?.capacity ?? roster.length;
    final count = activity?.participantCount ?? roster.length;
    return roster.take(count.clamp(0, capacity)).toList();
  }

  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 50));
}
