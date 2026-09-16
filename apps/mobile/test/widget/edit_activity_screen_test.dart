import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/presentation/edit_activity_screen.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';
import 'package:matchup_mobile/features/discovery/domain/activity_model.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

ActivityModel _activity() => ActivityModel(
      id: '9',
      title: 'Sunday Run',
      sportType: 'Running',
      description: 'Easy laps.',
      location: 'Auckland Domain',
      distanceKm: 1.2,
      dateTime: DateTime.now().add(const Duration(days: 2)),
      skillLevel: 'Beginner',
      capacity: 10,
      participantCount: 3,
      hostName: 'Sam',
      latitude: -36.8558,
      longitude: 174.7764,
    );

void main() {
  late _MockActivityRepository repo;

  setUp(() {
    repo = _MockActivityRepository();
    when(() => repo.byId('9')).thenAnswer((_) async => _activity());
    when(() => repo.updateActivity(
          activityId: any(named: 'activityId'),
          title: any(named: 'title'),
          sportType: any(named: 'sportType'),
          description: any(named: 'description'),
          locationName: any(named: 'locationName'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          geohash: any(named: 'geohash'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
          skillLevel: any(named: 'skillLevel'),
          capacity: any(named: 'capacity'),
          joinPolicy: any(named: 'joinPolicy'),
        )).thenAnswer((_) async {});
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/edit-activity/9'),
                child: const Text('Open edit'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/edit-activity/:id',
          builder: (_, state) =>
              EditActivityScreen(activityId: state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activityRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('Open edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('EditActivityScreen', () {
    testWidgets('should prefill fields from the activity', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Sunday Run'), findsOneWidget);
      expect(find.text('Auckland Domain'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('should submit only the changed fields', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).first, 'Sunday Sprint');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Diffed payload: only the title changed, everything else is null
      // (the repository skips nulls server-side).
      verify(() => repo.updateActivity(
            activityId: '9',
            title: 'Sunday Sprint',
            sportType: null,
            description: null,
            locationName: null,
            latitude: null,
            longitude: null,
            geohash: null,
            startTime: null,
            endTime: null,
            skillLevel: null,
            capacity: null,
            joinPolicy: null,
          )).called(1);
      // Success pops back home (the manage screen confirms in prod).
      expect(find.text('Edit Activity'), findsNothing);
      expect(find.text('Open edit'), findsOneWidget);
    });

    testWidgets('should block save with an empty title', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      verifyNever(() => repo.updateActivity(
            activityId: any(named: 'activityId'),
            title: any(named: 'title'),
            sportType: any(named: 'sportType'),
            description: any(named: 'description'),
            locationName: any(named: 'locationName'),
            latitude: any(named: 'latitude'),
            longitude: any(named: 'longitude'),
            geohash: any(named: 'geohash'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
            skillLevel: any(named: 'skillLevel'),
            capacity: any(named: 'capacity'),
            joinPolicy: any(named: 'joinPolicy'),
          ));
      expect(find.text('Please enter a title.'), findsOneWidget);
    });
  });
}
