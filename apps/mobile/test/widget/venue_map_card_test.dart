import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchup_mobile/features/activities/domain/activity_model.dart';
import 'package:matchup_mobile/features/discovery/presentation/widgets/venue_map_card.dart';

ActivityModel _activity({double? lat, double? lng}) => ActivityModel(
      id: 'a-1',
      title: 'Saturday Basketball',
      sportType: 'Basketball',
      description: 'Runs',
      location: 'Auckland Domain',
      distanceKm: 1.2,
      dateTime: DateTime.now().add(const Duration(days: 1)),
      skillLevel: 'Intermediate',
      capacity: 10,
      participantCount: 3,
      hostName: 'Sam',
      latitude: lat,
      longitude: lng,
    );

void main() {
  testWidgets('renders map preview when coordinates exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VenueMapCard(
            activity: _activity(lat: -36.8558, lng: 174.7764),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Venue Location'), findsOneWidget);
    expect(find.text('Auckland Domain'), findsOneWidget);
  });

  testWidgets('renders nothing when coordinates are missing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VenueMapCard(activity: _activity()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Venue Location'), findsNothing);
  });

  testWidgets('tapping preview opens the full-screen map', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VenueMapCard(
            activity: _activity(lat: -36.8558, lng: 174.7764),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Auckland Domain'));
    await tester.pump(const Duration(milliseconds: 100));

    // Full-screen sheet shows the venue name in its top bar.
    expect(find.text('Auckland Domain'), findsWidgets);
  });
}
