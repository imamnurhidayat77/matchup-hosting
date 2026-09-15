import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/domain/activity_participant.dart';
import 'package:matchup_mobile/features/activities/presentation/manage_activity_screen.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';
import 'package:matchup_mobile/features/discovery/domain/activity_model.dart';

class _MockActivityRepository extends Mock implements ActivityRepository {}

void main() {
  late _MockActivityRepository repo;

  setUp(() {
    repo = _MockActivityRepository();
    when(() => repo.cancel(any())).thenAnswer((_) async {});
    when(() => repo.joinRequests(any())).thenAnswer((_) async => []);
    when(() => repo.approveJoinRequest(any(), any())).thenAnswer((_) async {});
    when(() => repo.declineJoinRequest(any(), any())).thenAnswer((_) async {});
    when(
      () => repo.updateActivity(
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
      ),
    ).thenAnswer((_) async {});
  });

  ActivityModel activity({
    ActivityStatus status = ActivityStatus.available,
    String joinPolicy = 'open',
  }) {
    return ActivityModel(
      id: '5',
      title: 'Thursday Night Volleyball',
      sportType: 'Volleyball',
      description: '',
      location: 'Eastside Rec Centre',
      distanceKm: 2,
      dateTime: DateTime(2026, 8, 27, 19),
      skillLevel: 'Intermediate',
      capacity: 8,
      participantCount: 5,
      hostName: 'Noor Haddad',
      status: status,
      joinPolicy: joinPolicy,
      latitude: -36.8485,
      longitude: 174.7633,
    );
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/manage-activity/5',
      routes: [
        GoRoute(
          path: '/manage-activity/:id',
          builder: (_, state) =>
              ManageActivityScreen(activityId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/activity/:id/participants',
          builder: (_, _) => const Scaffold(body: Text('Participants')),
        ),
        GoRoute(
          path: '/edit-activity/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Edit ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/player-profile/:name',
          builder: (_, state) =>
              Scaffold(body: Text('Profile ${state.pathParameters['name']}')),
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
  }

  group('ManageActivityScreen', () {
    testWidgets(
      'should render real activity + roster data, not the old hardcoded seed',
      (tester) async {
        when(() => repo.byId('5')).thenAnswer((_) async => activity());
        when(() => repo.participants('5')).thenAnswer(
          (_) async => [
            ActivityParticipant(
              userId: 'host',
              name: 'Noor Haddad',
              avatarAsset: 'host_james.png',
              skillLevel: 'Advanced',
              joinedAt: DateTime.now().subtract(const Duration(days: 4)),
              isOrganizer: true,
              isCheckedIn: true,
            ),
            ActivityParticipant(
              userId: 'u2',
              name: 'Tavita Faleolo',
              avatarAsset: 'avatar_1.png',
              skillLevel: 'Beginner',
              joinedAt: DateTime.now().subtract(const Duration(hours: 6)),
              isOrganizer: false,
            ),
          ],
        );

        await pumpScreen(tester);

        expect(find.text('Thursday Night Volleyball'), findsOneWidget);
        expect(find.text('Noor Haddad'), findsOneWidget);
        expect(find.text('Tavita Faleolo'), findsOneWidget);
        expect(find.text('Participants (2)'), findsOneWidget);
        expect(find.text('CHECKED IN'), findsOneWidget);
        expect(find.text('PENDING'), findsOneWidget);
        // Old hardcoded seed content must be gone.
        expect(find.text('Friendly 5v5 Run at Prospect'), findsNothing);
        expect(find.text('James Wilson'), findsNothing);
      },
    );

    testWidgets(
      'should call activityRepository.cancel and pop after confirming cancel',
      (tester) async {
        when(() => repo.byId('5')).thenAnswer((_) async => activity());
        when(() => repo.participants('5')).thenAnswer((_) async => []);

        await pumpScreen(tester);
        await tester.scrollUntilVisible(
          find.text('Cancel Activity'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Cancel Activity'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel Activity').last);
        await tester.pumpAndSettle();

        verify(() => repo.cancel('5')).called(1);
      },
    );

    testWidgets(
      'should list pending join requests with approve/decline actions',
      (tester) async {
        when(() => repo.byId('5')).thenAnswer(
          (_) async => activity(joinPolicy: 'approval'),
        );
        when(() => repo.participants('5')).thenAnswer((_) async => []);
        when(() => repo.joinRequests('5')).thenAnswer(
          (_) async => [
            ActivityParticipant(
              userId: 'u9',
              name: 'Pending Petra',
              avatarAsset: 'avatar_1.png',
              skillLevel: 'Beginner',
              joinedAt: DateTime.now(),
              isOrganizer: false,
            ),
          ],
        );

        await pumpScreen(tester);
        await tester.scrollUntilVisible(
          find.text('Join requests (1)'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.text('Join requests (1)'), findsOneWidget);
        expect(find.text('Pending Petra'), findsOneWidget);
        expect(find.text('Approve'), findsOneWidget);
        expect(find.text('Decline'), findsOneWidget);

        await tester.tap(find.text('Approve'));
        await tester.pumpAndSettle();

        verify(() => repo.approveJoinRequest('5', 'u9')).called(1);
      },
    );

    testWidgets('should push participants when "View all" is tapped', (
      tester,
    ) async {
      when(() => repo.byId('5')).thenAnswer((_) async => activity());
      when(() => repo.participants('5')).thenAnswer(
        (_) async => [
          ActivityParticipant(
            userId: 'host',
            name: 'Noor Haddad',
            avatarAsset: 'host_james.png',
            skillLevel: 'Advanced',
            joinedAt: DateTime.now(),
            isOrganizer: true,
            isCheckedIn: true,
          ),
        ],
      );

      await pumpScreen(tester);
      final viewAll = find.text('View all');
      await tester.ensureVisible(viewAll);
      await tester.pumpAndSettle();
      await tester.tap(viewAll);
      await tester.pumpAndSettle();

      expect(find.text('Participants'), findsOneWidget);
    });
  
    testWidgets('should open the edit screen when Edit is tapped', (
      tester,
    ) async {
      when(() => repo.byId('5')).thenAnswer((_) async => activity());
      when(() => repo.participants('5')).thenAnswer((_) async => []);
      when(() => repo.joinRequests('5')).thenAnswer((_) async => []);

      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel('Edit activity'));
      await tester.pumpAndSettle();

      expect(find.text('Edit 5'), findsOneWidget);
    });

    testWidgets('should open the requester profile from the waiting list', (
      tester,
    ) async {
      when(() => repo.byId('5')).thenAnswer(
        (_) async => activity(joinPolicy: 'approval'),
      );
      when(() => repo.participants('5')).thenAnswer((_) async => []);
      when(() => repo.joinRequests('5')).thenAnswer(
        (_) async => [
          ActivityParticipant(
            userId: 'u9',
            name: 'Pending Petra',
            avatarAsset: 'avatar_1.png',
            skillLevel: 'Beginner',
            joinedAt: DateTime.now(),
            isOrganizer: false,
          ),
        ],
      );

      await pumpScreen(tester);
      await tester.scrollUntilVisible(
        find.text('Pending Petra'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      // NOTE: tapped by name text — AppTappable merges its explicit
      // label with child text, so bySemanticsLabel never exact-matches.
      await tester.tap(find.text('Pending Petra'));
      await tester.pumpAndSettle();

      expect(find.text('Profile Pending Petra'), findsOneWidget);
    });

    testWidgets('quick-edit sheet should call updateActivity on save', (
      tester,
    ) async {
      when(() => repo.byId('5')).thenAnswer((_) async => activity());
      when(() => repo.participants('5')).thenAnswer((_) async => []);
      when(() => repo.joinRequests('5')).thenAnswer((_) async => []);

      await pumpScreen(tester);

      // Quick-action "Edit" opens the bottom sheet (hero edit button
      // uses the 'Edit activity' semantics label, so text 'Edit' is unique).
      await tester.scrollUntilVisible(
        find.text('Edit'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Activity'), findsOneWidget);

      // The full edit sheet is scrollable — bring Save into view first.
      await tester.scrollUntilVisible(
        find.text('Save Changes'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      verify(
        () => repo.updateActivity(
          activityId: '5',
          title: 'Thursday Night Volleyball',
          sportType: 'Volleyball',
          description: '',
          locationName: 'Eastside Rec Centre',
          latitude: -36.8485,
          longitude: 174.7633,
          geohash: any(named: 'geohash'),
          startTime: DateTime(2026, 8, 27, 19),
          endTime: any(named: 'endTime'),
          skillLevel: 'Intermediate',
          capacity: 8,
          joinPolicy: 'open',
        ),
      ).called(1);
      // Sheet dismissed with a success confirmation.
      expect(find.text('Save Changes'), findsNothing);
      expect(find.text('Activity updated.'), findsOneWidget);
    });
  });
}
