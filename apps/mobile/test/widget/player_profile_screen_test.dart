import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/profile/data/user_repository.dart';
import 'package:matchup_mobile/features/profile/domain/user_model.dart';
import 'package:matchup_mobile/features/profile/presentation/player_profile_screen.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  late _MockUserRepository userRepo;

  setUp(() {
    userRepo = _MockUserRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/player-profile/James',
      routes: [
        GoRoute(
          path: '/player-profile/:name',
          builder: (_, state) =>
              PlayerProfileScreen(playerName: state.pathParameters['name']!),
        ),
        GoRoute(
          path: '/chat/:title',
          builder: (_, _) => const Scaffold(body: Text('Chat')),
        ),
        GoRoute(
          path: '/report/:type/:name',
          builder: (_, _) => const Scaffold(body: Text('Report')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [userRepositoryProvider.overrideWithValue(userRepo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PlayerProfileScreen', () {
    testWidgets('should render user details and stats', (tester) async {
      when(() => userRepo.byId('James')).thenAnswer(
        (_) async => const UserModel(
          id: 'james',
          displayName: 'James Wilson',
          rating: 4.9,
          activitiesCount: 24,
          hostedCount: 8,
          bio: 'Weekend warrior.',
          sports: [(sport: 'Basketball', level: 'Intermediate')],
        ),
      );

      await pumpScreen(tester);

      expect(find.text('JAMES WILSON'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Send Message'), findsOneWidget);
      expect(find.text('Report Profile'), findsOneWidget);
    });

    testWidgets('should show a not-found message when the player is null', (
      tester,
    ) async {
      when(() => userRepo.byId('James')).thenAnswer((_) async => null);
      await pumpScreen(tester);
      expect(find.text('Player not found.'), findsOneWidget);
    });

    testWidgets('should push chat when Message is tapped', (tester) async {
      when(() => userRepo.byId('James')).thenAnswer(
        (_) async => const UserModel(id: 'james', displayName: 'James Wilson'),
      );
      await pumpScreen(tester);

      await tester.tap(find.text('Send Message'));
      await tester.pumpAndSettle();
      expect(find.text('Chat'), findsOneWidget);
    });
  });
}
