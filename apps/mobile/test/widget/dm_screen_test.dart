import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matchup_mobile/core/providers/repository_providers.dart';
import 'package:matchup_mobile/features/chat/data/dm_repository.dart';
import 'package:matchup_mobile/features/chat/domain/chat_message.dart';
import 'package:matchup_mobile/features/chat/presentation/dm_screen.dart';

class _FakeDmRepo implements DmRepository {
  _FakeDmRepo({List<ChatMessage>? seed}) : _messages = List.of(seed ?? []) {
    _controller = StreamController<List<ChatMessage>>.broadcast(
      onListen: () => _controller.add(List.unmodifiable(_messages)),
    );
  }

  final List<ChatMessage> _messages;
  late final StreamController<List<ChatMessage>> _controller;
  final List<String> sent = [];

  @override
  Stream<List<ChatMessage>> watchMessages(String otherUid) => _controller.stream;

  @override
  Future<List<ChatMessage>> messages(String otherUid, {int limit = 50}) async =>
      List.unmodifiable(_messages);

  @override
  Future<ChatMessage> send({required String otherUid, required String text}) async {
    sent.add(text);
    final m = ChatMessage(
      id: 'm-${sent.length}',
      senderId: 'me',
      senderName: 'You',
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
    );
    _messages.add(m);
    _controller.add(List.unmodifiable(_messages));
    return m;
  }
}

ChatMessage _msg(String id, String senderId, String text) => ChatMessage(
      id: id,
      senderId: senderId,
      senderName: senderId == 'me' ? 'You' : 'Sam',
      text: text,
      sentAt: DateTime.now(),
      isMine: senderId == 'me',
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeDmRepo repo, {
  String peerName = 'Sam Rivera',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dmRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: DmScreen(otherUid: 'u-9', peerName: peerName),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('shows peer name, messages, and empty state', (tester) async {
    await _pump(tester, _FakeDmRepo());

    expect(find.text('Sam Rivera'), findsOneWidget);
    expect(find.text('Say hi to start the conversation.'), findsOneWidget);
  });

  testWidgets('renders incoming + outgoing bubbles', (tester) async {
    await _pump(
      tester,
      _FakeDmRepo(seed: [_msg('m-1', 'u-9', 'hey there'), _msg('m-2', 'me', 'hi!')]),
    );

    expect(find.text('hey there'), findsOneWidget);
    expect(find.text('hi!'), findsOneWidget);
  });

  testWidgets('sending appends the bubble and calls the repo', (tester) async {
    final repo = _FakeDmRepo();
    await _pump(tester, repo);

    await tester.enterText(find.byType(TextField), 'hello sam');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.sent, ['hello sam']);
    expect(find.text('hello sam'), findsOneWidget);
  });

  testWidgets('falls back to a generic title without a peer name', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dmRepositoryProvider.overrideWithValue(_FakeDmRepo())],
        child: const MaterialApp(home: DmScreen(otherUid: 'u-9')),
      ),
    );
    await tester.pump();

    expect(find.text('Direct message'), findsOneWidget);
  });
}
