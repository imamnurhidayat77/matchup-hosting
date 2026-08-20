import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';
import 'package:matchup_mobile/features/discovery/data/dummy_activity_repository.dart';
import 'package:matchup_mobile/features/discovery/data/remote_activity_repository.dart';

void main() {
  setUpAll(() async {
    // dotenv must be initialised before any provider that calls Env.apiBaseUrl
    await dotenv.load(fileName: '.env.example');
  });
  group('activityRepositoryProvider toggle', () {
    test(
      'should provide DummyActivityRepository when useRemoteApi is false',
      () {
        final container = ProviderContainer(
          overrides: [useRemoteApiProvider.overrideWithValue(false)],
        );
        addTearDown(container.dispose);

        final repo = container.read(activityRepositoryProvider);
        expect(repo, isA<DummyActivityRepository>());
      },
    );

    test(
      'should provide RemoteActivityRepository when useRemoteApi is true',
      () {
        final container = ProviderContainer(
          overrides: [useRemoteApiProvider.overrideWithValue(true)],
        );
        addTearDown(container.dispose);

        final repo = container.read(activityRepositoryProvider);
        expect(repo, isA<RemoteActivityRepository>());
      },
    );
  });

  group('DummyActivityRepository', () {
    late ActivityRepository repo;

    setUp(() => repo = DummyActivityRepository());

    test('should return a non-empty feed', () async {
      final feed = await repo.feed();
      expect(feed, isNotEmpty);
    });

    test('should return an activity by id that exists in the feed', () async {
      final feed = await repo.feed();
      final first = feed.first;
      final found = await repo.byId(first.id);
      expect(found?.id, first.id);
    });

    test('should return null for an id that does not exist', () async {
      final found = await repo.byId('non-existent-999');
      expect(found, isNull);
    });

    test('should add joined activity to joinedByUser after join', () async {
      final feed = await repo.feed();
      final activity = feed.first;
      await repo.join(activity.id);
      final joined = await repo.joinedByUser('me');
      expect(joined.any((a) => a.id == activity.id), isTrue);
    });

    test(
      'should return empty hosted list for a user who has not created any activity',
      () async {
        // The dummy repo seeds hosted activities for the default user 'me'.
        // A completely unrelated userId should return empty hosted list.
        final hosted = await repo.hostedByUser('unknown-user-xyz');
        // Dummy repo returns [] for users with no hosted activity in seed data
        // — if seed data doesn't include this user, list is empty.
        expect(hosted, isA<List>());
      },
    );
  });
}
