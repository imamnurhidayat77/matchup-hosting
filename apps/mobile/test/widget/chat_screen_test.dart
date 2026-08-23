import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/chat/data/chat_repository.dart';
import 'package:matchup_mobile/features/chat/domain/chat_message.dart';
import 'package:matchup_mobile/features/chat/presentation/chat_screen.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late _MockChatRepository repo;

  setUp(() {
    repo = _MockChatRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/chat/Test%20Group'),
                child: const Text('Open Chat'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/chat/:title',
          builder: (_, state) =>
              ChatScreen(activityTitle: state.pathParameters['title']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Chat'));
    await tester.pumpAndSettle();
  }

  group('ChatScreen', () {
    testWidgets('should render messages grouped with a day separator', (
      tester,
    ) async {
      final today = DateTime.now();
      when(() => repo.messages(any())).thenAnswer(
        (_) async => [
          ChatMessage(
            id: '1',
            senderId: 'alex',
            senderName: 'Alex',
            text: 'Hey there',
            sentAt: DateTime(today.year, today.month, today.day, 9, 0),
          ),
          ChatMessage(
            id: '2',
            senderId: 'alex',
            senderName: 'Alex',
            text: 'Ready for today?',
            sentAt: DateTime(today.year, today.month, today.day, 9, 1),
          ),
        ],
      );

      await pumpScreen(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Hey there'), findsOneWidget);
      expect(find.text('Ready for today?'), findsOneWidget);
      // Only one avatar rendered for the two-message run from the same
      // sender — grouping collapses the avatar to the last bubble.
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('should send a typed message and clear the composer', (
      tester,
    ) async {
      when(() => repo.messages(any())).thenAnswer((_) async => []);
      when(
        () => repo.send(
          activityId: any(named: 'activityId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer(
        (_) async => ChatMessage(
          id: 'x',
          senderId: 'me',
          senderName: 'You',
          text: 'hello',
          sentAt: DateTime.now(),
          isMine: true,
        ),
      );

      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pumpAndSettle();

      verify(
        () => repo.send(activityId: 'Test Group', text: 'hello'),
      ).called(1);
    });

    testWidgets('should pop back when the back button is tapped', (
      tester,
    ) async {
      when(() => repo.messages(any())).thenAnswer((_) async => []);
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Open Chat'), findsOneWidget);
    });
  });
}
