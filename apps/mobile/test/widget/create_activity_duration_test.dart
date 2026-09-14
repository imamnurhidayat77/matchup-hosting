import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/core/services/location_service.dart';
import 'package:matchup_mobile/features/activities/presentation/create_activity_screen.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  late _MockActivityRepository repo;

  setUp(() {
    repo = _MockActivityRepository();
    // Skip Geolocator — would stall in _submit().
    LocationService.debugGetCurrentLocation = () async => null;
  });

  tearDown(() {
    LocationService.debugGetCurrentLocation = null;
  });

  testWidgets('passes 60-minute duration to the repository', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [activityRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: CreateActivityScreen()),
    ));
    await tester.pumpAndSettle();

    // The 1h stepper button reads "Shorten duration" — tap it 4 times
    // (15-min steps × 4 = 60 min) from the 2h default.
    final shorten = find.bySemanticsLabel('Shorten duration');
    expect(shorten, findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(shorten);
      await tester.pump();
    }
    expect(find.text('1 hour'), findsOneWidget);
  });
}
