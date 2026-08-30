import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/presentation/check_in_screen.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';
import 'package:matchup_mobile/features/discovery/domain/activity_model.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  late _MockActivityRepository repo;

  setUp(() {
    repo = _MockActivityRepository();
  });

  ActivityModel activity() => ActivityModel(
    id: '3',
    title: 'Sunrise Yoga in the Park',
    sportType: 'Yoga',
    description: '',
    location: 'Meridian Gardens, Lawn B',
    distanceKm: 0.8,
    dateTime: DateTime(2026, 8, 22, 7),
    skillLevel: 'All levels',
    capacity: 15,
    participantCount: 9,
    hostName: 'Ines Coelho',
    durationMinutes: 60,
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activityRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: CheckInScreen(activityId: '3')),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('CheckInScreen', () {
    testWidgets(
      'should render real activity data from the repository, not the old hardcoded seed',
      (tester) async {
        when(() => repo.byId('3')).thenAnswer((_) async => activity());

        await pumpScreen(tester);

        expect(find.text('Sunrise Yoga in the Park'), findsOneWidget);
        expect(find.text('Meridian Gardens, Lawn B'), findsOneWidget);
        expect(find.text('Not checked in yet'), findsOneWidget);
        // Old hardcoded seed content must be gone.
        expect(find.text('Saturday Afternoon 5v5 Basketball'), findsNothing);
        expect(find.text('Central Park Court B'), findsNothing);
      },
    );

    testWidgets('should show "Checked in" after tapping Check In', (
      tester,
    ) async {
      when(() => repo.byId('3')).thenAnswer((_) async => activity());

      await pumpScreen(tester);
      await tester.tap(find.text('Check In'));
      await tester.pump();
      expect(find.text('Locating…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text('Checked in'), findsOneWidget);
      expect(find.text('Checked In'), findsOneWidget);
    });
  });
}
