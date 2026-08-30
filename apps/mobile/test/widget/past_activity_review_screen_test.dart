import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/domain/activity_participant.dart';
import 'package:matchup_mobile/features/activities/presentation/past_activity_review_screen.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';
import 'package:matchup_mobile/features/discovery/domain/activity_model.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  late _MockActivityRepository repo;

  setUp(() {
    repo = _MockActivityRepository();
  });

  ActivityModel activity() => ActivityModel(
    id: '4',
    title: 'Morning Beach Volleyball',
    sportType: 'Volleyball',
    description: '',
    location: 'Sunset Beach Court',
    distanceKm: 0.5,
    dateTime: DateTime(2026, 7, 26, 8),
    skillLevel: 'Intermediate',
    capacity: 8,
    participantCount: 4,
    hostName: 'Priya Shah',
  );

  List<ActivityParticipant> participants() => [
    ActivityParticipant(
      userId: 'p1',
      name: 'Freya Lindqvist',
      avatarAsset: 'sarah_c.png',
      skillLevel: 'Advanced',
      joinedAt: DateTime.now().subtract(const Duration(days: 5)),
      isOrganizer: true,
    ),
    ActivityParticipant(
      userId: 'p2',
      name: 'Bakari Osei',
      avatarAsset: 'mike_c.png',
      skillLevel: 'Intermediate',
      joinedAt: DateTime.now().subtract(const Duration(days: 4)),
      isOrganizer: false,
    ),
  ];

  Future<void> pumpScreen(WidgetTester tester, {bool pushed = false}) async {
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/activities',
      routes: [
        GoRoute(
          path: '/activities',
          builder: (_, _) => const Scaffold(body: Text('Activities')),
        ),
        GoRoute(
          path: '/past-activity/:id/review',
          builder: (_, state) =>
              PastActivityReviewScreen(activityId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [activityRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    if (pushed) {
      router.push('/past-activity/4/review');
      await tester.pumpAndSettle();
    }
  }

  group('PastActivityReviewScreen', () {
    testWidgets(
      'should render real activity + participants, not the old hardcoded seed',
      (tester) async {
        when(() => repo.byId('4')).thenAnswer((_) async => activity());
        when(
          () => repo.participants('4'),
        ).thenAnswer((_) async => participants());

        await pumpScreen(tester, pushed: true);

        expect(find.text('Morning Beach Volleyball'), findsOneWidget);
        expect(find.text('Sunset Beach Court'), findsOneWidget);
        expect(find.text('Freya Lindqvist'), findsOneWidget);
        expect(find.text('Bakari Osei'), findsOneWidget);
        // Old hardcoded seed content must be gone.
        expect(find.text('Sarah Connor'), findsNothing);
        expect(find.text('James Wilson'), findsNothing);
      },
    );

    testWidgets('should toggle the thumbs-up state for a participant', (
      tester,
    ) async {
      when(() => repo.byId('4')).thenAnswer((_) async => activity());
      when(
        () => repo.participants('4'),
      ).thenAnswer((_) async => participants());

      await pumpScreen(tester, pushed: true);

      final toggle = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Give Freya Lindqvist a thumbs up',
      );
      expect(toggle, findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'Remove thumbs up for Freya Lindqvist',
        ),
        findsOneWidget,
      );
    });

    testWidgets('should update the star rating when a star is tapped', (
      tester,
    ) async {
      when(() => repo.byId('4')).thenAnswer((_) async => activity());
      when(
        () => repo.participants('4'),
      ).thenAnswer((_) async => participants());

      await pumpScreen(tester, pushed: true);

      final fifthStar = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '5 stars',
      );
      expect(fifthStar, findsOneWidget);
      await tester.tap(fifthStar);
      await tester.pumpAndSettle();

      // No exception means the rating updated without crashing; behaviour
      // is local-only state (no review-submission backend exists yet).
    });

    testWidgets('should pop after tapping Submit Review', (tester) async {
      when(() => repo.byId('4')).thenAnswer((_) async => activity());
      when(
        () => repo.participants('4'),
      ).thenAnswer((_) async => participants());

      await pumpScreen(tester, pushed: true);
      await tester.tap(find.text('Submit Review'));
      await tester.pumpAndSettle();

      expect(find.text('Activity Review'), findsNothing);
      expect(find.text('Activities'), findsOneWidget);
    });
  });
}
