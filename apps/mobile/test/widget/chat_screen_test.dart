import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/activities/domain/activity_model.dart';
import 'package:matchup_mobile/features/activities/domain/activity_participant.dart';
import 'package:matchup_mobile/features/chat/data/chat_repository.dart';
import 'package:matchup_mobile/features/chat/data/typing_repository.dart';
import 'package:matchup_mobile/features/chat/domain/chat_message.dart';
import 'package:matchup_mobile/features/chat/presentation/chat_screen.dart';
import 'package:matchup_mobile/features/discovery/data/activity_repository.dart';

class _MockChatRepository extends Mock implements ChatRepository {}

class _MockActivityRepository extends Mock implements ActivityRepository {}

class _MockTypingRepository extends Mock implements TypingRepository {}

void main() {
  late _MockChatRepository repo;
  late _MockActivityRepository activityRepo;
  late _MockTypingRepository typingRepo;

  ActivityModel testActivity() => ActivityModel(
        id: 'Test Group',
        title: 'Test Group',
        sportType: 'Basketball',
        description: 'A test activity',
        location: 'Test Location',
        distanceKm: 1.0,
        dateTime: DateTime.now().add(const Duration(days: 1)),
        skillLevel: 'Intermediate',
        capacity: 10,
        participantCount: 1,
        hostName: 'Host',
      );

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    repo = _MockChatRepository();
    activityRepo = _MockActivityRepository();
    typingRepo = _MockTypingRepository();
    // setTyping is fire-and-forget from the input listener — no-op it
    // so the test never touches the default RemoteTypingRepository
    // (which would open a real HTTP connection to the backend).
    when(
      () => typingRepo.setTyping(
        activityId: any(named: 'activityId'),
        isTyping: any(named: 'isTyping'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => typingRepo.isTyping(
        activityId: any(named: 'activityId'),
        uid: any(named: 'uid'),
      ),
    ).thenAnswer((_) async => false);
    when(
      () => typingRepo.watchTyping(
        activityId: any(named: 'activityId'),
        uids: any(named: 'uids'),
      ),
    ).thenAnswer((_) => Stream.value(const <String>{}));
    // Defaults for the calls every test needs but rarely overrides.
    // Set here (not in pumpScreen) so a test's own `when(...)` stub
    // — registered after setUp, before pumpScreen — takes precedence.
    when(
      () => repo.watchMessages(any()),
    ).thenAnswer((_) => Stream.value(const <ChatMessage>[]));
    when(
      () => activityRepo.byId(any()),
    ).thenAnswer((_) async => testActivity());
    when(
      () => activityRepo.participants(any()),
    ).thenAnswer((_) async => const <ActivityParticipant>[]);
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
          path: '/chat/:id',
          builder: (_, state) =>
              ChatScreen(activityId: state.pathParameters['id']!),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repo),
          activityRepositoryProvider.overrideWithValue(activityRepo),
          typingRepositoryProvider.overrideWithValue(typingRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open Chat'));
    // Chat has a few cascading async providers (activity, participants,
    // typing stream) — pump a few frames instead of pumpAndSettle, which
    // can time out if any periodic timer sneaks in through a default
    // provider.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('ChatScreen', () {
    testWidgets('should render messages grouped with a day separator', (
      tester,
    ) async {
      final today = DateTime.now();
      when(() => repo.watchMessages(any())).thenAnswer(
        (_) => Stream.value([
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
        ]),
      );

      await pumpScreen(tester);

      // 'TODAY' appears twice: the match banner badge + the day separator.
      expect(find.text('TODAY'), findsWidgets);
      expect(find.text('Hey there'), findsOneWidget);
      expect(find.text('Ready for today?'), findsOneWidget);
      // Only one avatar rendered for the two-message run from the same
      // sender — grouping collapses the avatar to the last bubble.
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('should send a typed message and clear the composer', (
      tester,
    ) async {
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
      // Let the input listener run + the send button's enabled state
      // rebuild before tapping.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      verify(
        () => repo.send(activityId: 'Test Group', text: 'hello'),
      ).called(1);
    });

    testWidgets('should pop back when the back button is tapped', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Open Chat'), findsOneWidget);
    });
  });
}
