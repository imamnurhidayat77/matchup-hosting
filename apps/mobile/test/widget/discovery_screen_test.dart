import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/domain/activity_model.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';
import 'package:matchup_mobile/features/discovery/presentation/discovery_screen.dart';
import 'package:matchup_mobile/features/notifications/data/notification_repository.dart';
import 'package:matchup_mobile/features/notifications/domain/app_notification.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

List<ActivityModel> _fixtures() => [
  ActivityModel(
    id: '1',
    title: 'Saturday Basketball',
    sportType: 'Basketball',
    description: 'Fun pickup game.',
    location: 'Central Park',
    distanceKm: 2.0,
    dateTime: DateTime.now().add(const Duration(hours: 3)),
    skillLevel: 'Intermediate',
    capacity: 10,
    participantCount: 6,
    hostName: 'Alex',
  ),
  ActivityModel(
    id: '2',
    title: 'Tennis Doubles',
    sportType: 'Tennis',
    description: 'Doubles match.',
    location: 'City Courts',
    distanceKm: 3.5,
    dateTime: DateTime.now().add(const Duration(days: 1)),
    skillLevel: 'Beginner',
    capacity: 4,
    participantCount: 2,
    hostName: 'Sam',
  ),
];

void main() {
  late _MockActivityRepository activityRepo;
  late _MockNotificationRepository notifRepo;

  setUp(() {
    activityRepo = _MockActivityRepository();
    notifRepo = _MockNotificationRepository();
    when(
      () => activityRepo.feed(
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => _fixtures());
    when(
      () => notifRepo.all(),
    ).thenAnswer((_) async => const <AppNotification>[]);
  });

  Future<GoRouter> pumpDiscovery(WidgetTester tester) async {
    // Discovery cards are laid out for a real phone frame — the default
    // 800×600 test surface is too short and the overlapping stacked cards
    // overflow their Column, which fails the test on an unrelated render
    // error before assertions even run.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/discovery',
      routes: [
        GoRoute(path: '/discovery', builder: (_, _) => const DiscoveryScreen()),
        GoRoute(
          path: '/activity/:id',
          builder: (_, state) => Scaffold(
            body: Text('Activity Detail ${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/preferences',
          builder: (_, _) => const Scaffold(body: Text('Preferences')),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const Scaffold(body: Text('Notifications')),
        ),
        GoRoute(
          path: '/match/:id',
          builder: (_, _) => const Scaffold(body: Text('Match')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activityRepositoryProvider.overrideWithValue(activityRepo),
          notificationRepositoryProvider.overrideWithValue(notifRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('DiscoveryScreen', () {
    testWidgets('should render the top activity title', (tester) async {
      await pumpDiscovery(tester);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Saturday Basketball'), findsOneWidget);
    });

    testWidgets(
      'should push the activity detail route when the card is tapped',
      (tester) async {
        await pumpDiscovery(tester);
        await tester.tap(find.text('Saturday Basketball'));
        await tester.pumpAndSettle();
        expect(find.text('Activity Detail 1'), findsOneWidget);
      },
    );

    testWidgets('should navigate to filters when the filter icon is tapped', (
      tester,
    ) async {
      await pumpDiscovery(tester);
      await tester.tap(find.bySemanticsLabel('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Preferences'), findsOneWidget);
    });

    testWidgets(
      'should advance to the next card when the join button is tapped',
      (tester) async {
        await pumpDiscovery(tester);
        expect(find.text('Saturday Basketball'), findsOneWidget);

        await tester.tap(find.text('Join game'));
        // The exit animation (~320ms) plays before the navigation Future
        // (420ms delay) fires — settle both.
        await tester.pumpAndSettle(const Duration(milliseconds: 600));

        expect(find.text('Match'), findsOneWidget);
      },
    );

    testWidgets('should show an empty state once the deck is exhausted', (
      tester,
    ) async {
      when(
        () => activityRepo.feed(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => [_fixtures().first]);

      await pumpDiscovery(tester);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text("You're all caught up"), findsOneWidget);
    });
  });
}
