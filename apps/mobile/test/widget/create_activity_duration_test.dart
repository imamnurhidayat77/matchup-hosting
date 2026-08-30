import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/domain/activity_model.dart';
import 'package:matchup_mobile/features/activities/presentation/create_activity_screen.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';

/// Regression coverage for the Duration field (PRD Section 1.4): Create
/// Activity previously had no way to capture how long an activity runs, so
/// the detail screen faked the end time as `start + 2h`. This confirms the
/// segmented control actually reaches `ActivityRepository.create` — now
/// exercised through the two-step wizard (Setup → Rules → Preview → Create).
class _MockActivityRepository extends Mock implements ActivityRepository {}

ActivityModel _created() => ActivityModel(
  id: '99',
  title: 'Weekend Basketball Runs',
  sportType: 'Basketball',
  description: '',
  location: 'Test Venue',
  distanceKm: 0,
  dateTime: DateTime.now().add(const Duration(days: 1)),
  skillLevel: 'Intermediate',
  capacity: 10,
  participantCount: 1,
  hostName: 'You',
);

void main() {
  late _MockActivityRepository repo;

  setUp(() {
    repo = _MockActivityRepository();
    when(
      () => repo.create(
        title: any(named: 'title'),
        sportType: any(named: 'sportType'),
        location: any(named: 'location'),
        dateTime: any(named: 'dateTime'),
        maxParticipants: any(named: 'maxParticipants'),
        skillLevel: any(named: 'skillLevel'),
        fee: any(named: 'fee'),
        durationMinutes: any(named: 'durationMinutes'),
      ),
    ).thenAnswer((_) async => _created());
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // A tall surface so the whole wizard step renders without lazy-list
    // culling getting in the way of taps.
    await tester.binding.setSurfaceSize(const Size(420, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/create',
      routes: [
        GoRoute(
          path: '/create',
          builder: (_, _) => const CreateActivityScreen(),
        ),
        GoRoute(
          path: '/activities',
          builder: (_, _) => const Scaffold(body: Text('Activities')),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [activityRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CreateActivityScreen — Duration field', () {
    testWidgets('should default to 2h selected when the setup step opens', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
    });

    testWidgets(
      'should pass the selected duration to ActivityRepository.create '
      'when the wizard is completed',
      (tester) async {
        await pumpScreen(tester);

        // Step 1 (Setup): fill the required fields via the UI. The title is
        // the first text field, the location the second.
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Weekend Basketball Runs');
        await tester.enterText(fields.at(1), 'Test Venue');
        await tester.pumpAndSettle();

        // Choose the 1h duration instead of the 2h default.
        await tester.tap(find.text('1h'));
        await tester.pumpAndSettle();

        // Advance: Setup → Rules → Preview.
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Preview activity'));
        await tester.pumpAndSettle();

        // Preview → create.
        await tester.tap(find.text('Create Activity'));
        await tester.pumpAndSettle();

        final captured = verify(
          () => repo.create(
            title: any(named: 'title'),
            sportType: any(named: 'sportType'),
            location: any(named: 'location'),
            dateTime: any(named: 'dateTime'),
            maxParticipants: any(named: 'maxParticipants'),
            skillLevel: any(named: 'skillLevel'),
            fee: any(named: 'fee'),
            durationMinutes: captureAny(named: 'durationMinutes'),
          ),
        ).captured;

        expect(captured.single, 60);
      },
    );
  });
}
