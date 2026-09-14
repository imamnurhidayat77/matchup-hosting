import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/domain/activity_model.dart';
import 'package:matchup_mobile/features/activities/domain/activity_participant.dart';
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

ActivityModel _approvalFixture({String? joinRequestStatus}) => ActivityModel(
  id: 'a-2',
  title: 'Sunday Tennis Approval',
  sportType: 'Tennis',
  description: 'Host-approved session.',
  location: 'Domain Courts',
  distanceKm: 1.2,
  dateTime: DateTime(2026, 8, 23, 10),
  skillLevel: 'Beginner',
  capacity: 4,
  participantCount: 1,
  hostName: 'Sarah Chen',
  joinPolicy: 'approval',
  joinRequestStatus: joinRequestStatus,
);

void main() {
  late _MockActivityRepository repo;

  setUp(() {
    repo = _MockActivityRepository();
    when(() => repo.byId(any())).thenAnswer((_) async => _fixture());
    when(() => repo.join(any())).thenAnswer((_) async {});
    // The participant stack reads the live roster — default to empty so
    // tests never touch the network.
    when(
      () => repo.participants(any()),
    ).thenAnswer((_) async => <ActivityParticipant>[]);
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

      // NOTE: find.bySemanticsLabel('Join Game') finds 0 nodes here even
      // though the Semantics widget exists — the label merges with the
      // 'Join Game' text child in the semantics tree. Match the Text instead.
      final joinButton = find.text('Join Game');
      expect(
        joinButton,
        findsOneWidget,
        reason: 'Join button not found in tree',
      );

      await tester.ensureVisible(joinButton);
      await tester.tap(joinButton);
      await tester.pump(); // start the async join
      await tester.pumpAndSettle();

      verify(() => repo.join('a-1')).called(1);
    });

    testWidgets(
      'approval activity shows Request to Join and files a request on tap',
      (tester) async {
        when(() => repo.byId(any())).thenAnswer((_) async => _approvalFixture());
        when(() => repo.requestJoin(any())).thenAnswer((_) async {});

        await pumpViaRealNavigation(
          tester,
          repo: repo,
          via: (context) => context.push('/activity/a-2'),
        );

        final requestButton = find.text('Request to Join');
        expect(requestButton, findsOneWidget);

        await tester.ensureVisible(requestButton);
        await tester.tap(requestButton);
        await tester.pump(); // start the async request
        await tester.pumpAndSettle();

        verify(() => repo.requestJoin('a-2')).called(1);
        expect(find.text('Request pending'), findsOneWidget);
      },
    );

    testWidgets(
      'pending request renders a disabled pill and never calls requestJoin',
      (tester) async {
        when(
          () => repo.byId(any()),
        ).thenAnswer((_) async => _approvalFixture(joinRequestStatus: 'pending'));
        when(() => repo.requestJoin(any())).thenAnswer((_) async {});

        await pumpViaRealNavigation(
          tester,
          repo: repo,
          via: (context) => context.push('/activity/a-2'),
        );

        expect(find.text('Request pending'), findsOneWidget);
        // Disabled pill: tapping must not file anything.
        await tester.tap(find.text('Request pending'));
        await tester.pumpAndSettle();

        verifyNever(() => repo.requestJoin(any()));
      },
    );

    testWidgets('report button opens the report bottom sheet when tapped', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/activity/a-1',
        routes: [
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

      final reportButton = find.text('Report Activity');
      expect(reportButton, findsOneWidget);

      await tester.ensureVisible(reportButton);
      await tester.tap(reportButton);
      await tester.pumpAndSettle();

      // Reporting is a modal bottom sheet now (not a pushed route):
      // the sheet header + reason list + submit bar appear on top of the
      // still-visible detail screen.
      expect(find.text("What's the issue?"), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
    });
  });
}
