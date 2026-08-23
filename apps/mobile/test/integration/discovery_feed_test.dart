import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/domain/activity_model.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockActivityRepository extends Mock implements ActivityRepository {}

// ─── Fixtures ─────────────────────────────────────────────────────────────────

ActivityModel _fixture({String id = 'a-1', String title = 'Test Activity'}) =>
    ActivityModel(
      id: id,
      title: title,
      sportType: 'Basketball',
      description: 'A test activity',
      location: 'Test Location',
      distanceKm: 1.0,
      dateTime: DateTime.now().add(const Duration(days: 1)),
      skillLevel: 'Intermediate',
      capacity: 10,
      participantCount: 4,
      hostName: 'Host',
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(0);
  });

  group('activityFeedProvider', () {
    test('should resolve to a list of activities from repository', () async {
      final mock = _MockActivityRepository();
      final activities = [_fixture(id: '1'), _fixture(id: '2')];

      when(
        () => mock.feed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => activities);

      final container = ProviderContainer(
        overrides: [activityRepositoryProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      // Initially loading
      final initial = container.read(activityFeedProvider);
      expect(initial, isA<AsyncLoading>());

      // Await resolution
      await container.read(activityFeedProvider.future);
      final result = container.read(activityFeedProvider);
      expect(result.hasValue, isTrue);
      expect(result.value, hasLength(2));
    });

    test('should surface error when repository throws', () async {
      final mock = _MockActivityRepository();

      when(
        () => mock.feed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenThrow(Exception('Network failure'));

      final container = ProviderContainer(
        overrides: [activityRepositoryProvider.overrideWithValue(mock)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(activityFeedProvider.future),
        throwsA(isA<Exception>()),
      );

      final result = container.read(activityFeedProvider);
      expect(result.hasError, isTrue);
    });

    test(
      'should return empty list when repository returns no activities',
      () async {
        final mock = _MockActivityRepository();

        when(
          () => mock.feed(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => <ActivityModel>[]);

        final container = ProviderContainer(
          overrides: [activityRepositoryProvider.overrideWithValue(mock)],
        );
        addTearDown(container.dispose);

        final result = await container.read(activityFeedProvider.future);
        expect(result, isEmpty);
      },
    );
  });

  group('DummyActivityRepository integration (no mocks)', () {
    test('should complete full create → join → joinedByUser flow', () async {
      final container = ProviderContainer(
        overrides: [useRemoteApiProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      final repo = container.read(activityRepositoryProvider);

      // Create a new activity
      final created = await repo.create(
        title: 'Integration Test Activity',
        sportType: 'Soccer',
        location: 'Test Venue',
        dateTime: DateTime.now().add(const Duration(days: 2)),
        maxParticipants: 8,
        skillLevel: 'Beginner',
        fee: 0,
      );
      expect(created.title, 'Integration Test Activity');

      // Join it
      await repo.join(created.id);

      // Verify it appears in joined list
      final joined = await repo.joinedByUser('me');
      expect(joined.any((a) => a.id == created.id), isTrue);
    });
  });
}
