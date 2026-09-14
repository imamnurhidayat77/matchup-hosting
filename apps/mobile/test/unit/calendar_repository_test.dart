import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchup_mobile/features/calendar/data/calendar_repository_impl.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';
import 'package:matchup_mobile/features/discovery/domain/activity_model.dart';

ActivityModel _game({
  required String id,
  required DateTime start,
  int durationMinutes = 120,
}) =>
    ActivityModel(
      id: id,
      title: 'Game $id',
      sportType: 'Tennis',
      description: '',
      location: 'Courts',
      distanceKm: 1.0,
      dateTime: start,
      skillLevel: 'Beginner',
      capacity: 4,
      participantCount: 2,
      hostName: 'Sam',
      durationMinutes: durationMinutes,
    );

class _FakeActivities implements ActivityRepository {
  _FakeActivities({required this.joined, required this.hosted});
  final List<ActivityModel> joined;
  final List<ActivityModel> hosted;

  @override
  Future<List<ActivityModel>> feed({
    int limit = 20,
    int offset = 0,
    filter,
    bool forceRefresh = false,
  }) async =>
      const [];

  @override
  Future<List<ActivityModel>> joinedByUser(String userId) async => joined;

  @override
  Future<List<ActivityModel>> hostedByUser(String userId) async => hosted;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  setUpAll(() {
    // ApiClient reads Env at construction (dotenv asset, not loaded in
    // unit tests) and SecureTokenStore hits a platform channel.
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('RemoteCalendarRepository.upcoming (derived)', () {
    testWidgets('merges joined + hosted, sorted, skips past', (tester) async {
      final now = DateTime.now();
      final repo = RemoteCalendarRepository(
        activities: _FakeActivities(
          joined: [
            _game(id: 'past', start: now.subtract(const Duration(days: 2))),
            _game(id: 'j1', start: now.add(const Duration(days: 2))),
          ],
          hosted: [
            _game(id: 'h1', start: now.add(const Duration(days: 1))),
            // Duplicate id across both lists appears once.
            _game(id: 'j1', start: now.add(const Duration(days: 2))),
          ],
        ),
      );

      final events = await repo.upcoming(days: 30);

      expect(events.map((e) => e.activityId), ['h1', 'j1']);
      expect(events.first.title, 'Game h1');
      expect(events.first.addedToDeviceCalendar, isFalse);
    });

    testWidgets('respects the horizon', (tester) async {
      final now = DateTime.now();
      final repo = RemoteCalendarRepository(
        activities: _FakeActivities(
          joined: [_game(id: 'far', start: now.add(const Duration(days: 60)))],
          hosted: const [],
        ),
      );

      expect(await repo.upcoming(days: 30), isEmpty);
    });
  });
}
