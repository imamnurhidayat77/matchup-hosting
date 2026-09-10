import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/chat/data/chat_repository.dart';
import 'package:matchup_mobile/features/chat/domain/chat_message.dart';
import 'package:matchup_mobile/features/notifications/data/notification_repository.dart';
import 'package:matchup_mobile/features/notifications/domain/app_notification.dart';
import 'package:matchup_mobile/features/chat/presentation/messages_screen.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

List<ChatConversation> _fixtures() => const [
  ChatConversation(
    id: '1',
    name: 'Friendly 5v5 Basketball',
    lastMessage: 'Alex: bringing the ball',
    time: '2m ago',
    unreadCount: 3,
    isGroup: true,
  ),
  ChatConversation(
    id: '2',
    name: 'Marcus Vance',
    lastMessage: 'Sure, court #2',
    time: 'Yesterday',
  ),
];

void main() {
  late _MockChatRepository chatRepo;
  late _MockNotificationRepository notifRepo;

  setUp(() {
    chatRepo = _MockChatRepository();
    notifRepo = _MockNotificationRepository();
    when(() => chatRepo.conversations()).thenAnswer((_) async => _fixtures());
    when(
      () => notifRepo.all(),
    ).thenAnswer((_) async => const <AppNotification>[]);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/messages',
      routes: [
        GoRoute(path: '/messages', builder: (_, _) => const MessagesScreen()),
        GoRoute(
          // The real router uses `:id` (activity id) — see
          // `app/router.dart`. The test placeholder renders the raw
          // id so the assertion can verify the right activity was
          // selected.
          path: '/chat/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Chat ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const Scaffold(body: Text('Notifications')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(chatRepo),
          notificationRepositoryProvider.overrideWithValue(notifRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MessagesScreen', () {
    testWidgets('should render every conversation', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Friendly 5v5 Basketball'), findsOneWidget);
      expect(find.text('Marcus Vance'), findsOneWidget);
    });

    testWidgets('should push the chat route when a row is tapped', (
      tester,
    ) async {
      await pumpScreen(tester);
      // Tap the second conversation (id = '2'). The route now uses
      // the activity id rather than the display name.
      await tester.tap(find.text('Marcus Vance'));
      await tester.pumpAndSettle();
      expect(find.text('Chat 2'), findsOneWidget);
    });

    testWidgets('should filter conversations as the search query changes', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'Marcus');
      await tester.pumpAndSettle();

      expect(find.text('Marcus Vance'), findsOneWidget);
      expect(find.text('Friendly 5v5 Basketball'), findsNothing);
    });

    testWidgets('should show an empty state when there are no matches', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.enterText(find.byType(TextField), 'zzz-no-match');
      await tester.pumpAndSettle();

      expect(find.text('No results'), findsOneWidget);
    });
  });
}
