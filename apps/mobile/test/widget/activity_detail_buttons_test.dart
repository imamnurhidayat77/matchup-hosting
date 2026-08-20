import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/domain/activity_model.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';
import 'package:matchup_mobile/features/discovery/presentation/activity_detail_screen.dart';

/// Reproduces the user-reported bug: "tombol-tombol nya gabisa dipencet,
/// semuanya" (none of the buttons on the activity detail screen are
/// tappable). These tests actually pump the widget tree and tap each
/// button rather than just reading the source, so a hit-testing regression
/// (e.g. a widget silently absorbing taps) shows up as a failing test.
class _MockActivityRepository extends Mock implements ActivityRepository {}

ActivityModel _fixture() => ActivityModel(
      id: 'a-1',
      title: 'Saturday Afternoon 5v5 Basketball',
      sportType: 'Basketball',
      description: 'Looking for intermediate players.',
      location: 'Central Park Court B',
      addressLine: 'Central Park, New York, NY',
      distanceKm: 2.4,
      dateTime: DateTime(2026, 8, 20, 16),
      skillLevel: 'Intermediate',
      capacity: 10,
      participantCount: 6,
      hostName: 'James Wilson',
    );

void main() {
  late _MockActivityRepository repo;

  setUp(() {
    repo = _MockActivityRepository();
    when(() => repo.byId(any())).thenAnswer((_) async => _fixture());
    when(() => repo.join(any())).thenAnswer((_) async {});
  });

  /// Builds a router that starts on a "Home" screen and only reaches the
  /// detail screen via a real navigation action — [via]. This is what
  /// actually distinguishes the bug: `context.go('/activity/:id')` replaces
  /// the whole stack (nothing left to pop back to), while
  /// `context.push('/activity/:id')` layers it on top (back/dislike can pop
  /// back to Home). A router built with `initialLocation: '/activity/a-1'`
  /// can't tell these apart because there's no prior route either way —
  /// that gap is why the previous version of this test passed despite the
  /// button being effectively dead on the real navigation path.
  Future<GoRouter> pumpViaRealNavigation(
    WidgetTester tester, {
    required ActivityRepository repo,
    required void Function(BuildContext) via,
  }) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => via(context),
                child: const Text('Open Activity'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/activity/:id',
          builder: (_, state) =>
              ActivityDetailScreen(activityId: state.pathParameters['id']!),
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

    await tester.tap(find.text('Open Activity'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityDetailScreen), findsOneWidget);

    return router;
  }

  group('ActivityDetailScreen buttons', () {
    testWidgets(
      'back button actually returns to the previous screen when reached via push',
      (tester) async {
        await pumpViaRealNavigation(
          tester,
          repo: repo,
          via: (context) => context.push('/activity/a-1'),
        );

        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();

        expect(
          find.text('Open Activity'),
          findsOneWidget,
          reason: 'Back button did not return to the previous screen',
        );
      },
    );

    testWidgets(
      'back button is a dead tap when the screen was reached via go() '
      '(this is the bug report: "tombol back gabisa dipencet")',
      (tester) async {
        await pumpViaRealNavigation(
          tester,
          repo: repo,
          via: (context) => context.go('/activity/a-1'),
        );

        await tester.tap(find.bySemanticsLabel('Back'));
        await tester.pumpAndSettle();

        // go() wipes the stack, so maybePop() has nothing to pop to. The
        // detail screen is expected to still be on screen — this documents
        // the exact failure mode, not a desired outcome.
        expect(find.byType(ActivityDetailScreen), findsOneWidget);
      },
    );

    testWidgets(
      'dislike (X) button actually returns to the previous screen when reached via push',
      (tester) async {
        await pumpViaRealNavigation(
          tester,
          repo: repo,
          via: (context) => context.push('/activity/a-1'),
        );

        await tester.tap(find.bySemanticsLabel('Not interested'));
        await tester.pumpAndSettle();

        expect(
          find.text('Open Activity'),
          findsOneWidget,
          reason: 'Dislike button did not return to the previous screen',
        );
      },
    );

    testWidgets('join (heart) button calls repository.join when tapped', (
      tester,
    ) async {
      await pumpViaRealNavigation(
        tester,
        repo: repo,
        via: (context) => context.push('/activity/a-1'),
      );

      final joinButton = find.bySemanticsLabel('Join activity');
      expect(joinButton, findsOneWidget, reason: 'Join button not found in tree');

      await tester.ensureVisible(joinButton);
      await tester.tap(joinButton);
      await tester.pump(); // start the async join
      await tester.pumpAndSettle();

      verify(() => repo.join('a-1')).called(1);
    });

    testWidgets('report button navigates to the report route when tapped', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/activity/a-1',
        routes: [
          GoRoute(
            path: '/activity/:id',
            builder: (_, state) => ActivityDetailScreen(
              activityId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/report/activity/:id',
            builder: (_, _) => const Scaffold(body: Text('Report Screen')),
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

      final reportButton = find.text('Report Activity');
      expect(reportButton, findsOneWidget);

      await tester.ensureVisible(reportButton);
      await tester.tap(reportButton);
      await tester.pumpAndSettle();

      expect(find.text('Report Screen'), findsOneWidget);
    });
  });
}
