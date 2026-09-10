import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/rtdb_auth_service.dart';
import '../../../core/storage/secure_token_store.dart';
import '../domain/chat_message.dart';

/// Canonical 1-on-1 thread id — sorted uids joined with `_`, mirroring
/// backend `dmThreadId` in `database/paths.ts`. Both directions map to
/// the same conversation.
String dmThreadId(String uidA, String uidB) {
  final pair = [uidA.trim(), uidB.trim()]..sort();
  return '${pair[0]}_${pair[1]}';
}

/// Read contract for 1-on-1 direct messages.
///
/// Minimal scope: text messages only (no images/locations), realtime
/// via RTDB with HTTP polling fallback — same shape as the group chat
/// repository so a future merge is mechanical.
abstract class DmRepository {
  Stream<List<ChatMessage>> watchMessages(String otherUid);
  Future<List<ChatMessage>> messages(String otherUid, {int limit = 50});
  Future<ChatMessage> send({required String otherUid, required String text});
}

/// HTTP + RTDB implementation against `/api/dm/:uid/...`.
class RemoteDmRepository implements DmRepository {
  RemoteDmRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<String> _myUid() async =>
      await SecureTokenStore.instance.readUserId() ?? '';

  @override
  Stream<List<ChatMessage>> watchMessages(String otherUid) async* {
    // RTDB first, HTTP polling fallback — mirrors RemoteChatRepository.
    try {
      await RtdbAuthService.instance.ensureSignedIn();
      final myUid = await _myUid();
      final ref = FirebaseDatabase.instance.ref(
        'dmChats/${dmThreadId(myUid, otherUid)}/messages',
      );
      await for (final event in ref.onValue) {
        yield _parseList(event.snapshot.value, myUid: myUid);
      }
      return;
    } catch (e, st) {
      debugPrint('[RemoteDmRepository.watchMessages] RTDB failed, polling: $e\n$st');
    }
    // Polling fallback.
    while (true) {
      yield await messages(otherUid);
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  @override
  Future<List<ChatMessage>> messages(String otherUid, {int limit = 50}) async {
    try {
      final res = await _client.dio.get(
        '/dm/$otherUid/messages',
        queryParameters: {'limit': limit},
      );
      final myUid = await _myUid();
      final rows = apiDataList(res.data);
      return [
        for (final e in rows)
          if (e is Map<String, dynamic>) _parseOne(e, myUid: myUid),
      ];
    } catch (e, st) {
      debugPrint('[RemoteDmRepository.messages] $e\n$st');
      return const [];
    }
  }

  @override
  Future<ChatMessage> send({
    required String otherUid,
    required String text,
  }) async {
    final res = await _client.dio.post(
      '/dm/$otherUid/messages',
      data: {'text': text},
    );
    final messageId =
        apiDataMap(res.data)?['messageId']?.toString() ??
            '${DateTime.now().millisecondsSinceEpoch}';
    final myUid = await _myUid();
    return ChatMessage(
      id: messageId,
      senderId: myUid,
      senderName: 'You',
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
    );
  }

  List<ChatMessage> _parseList(Object? value, {required String myUid}) {
    if (value is! Map) return const [];
    final out = <ChatMessage>[];
    for (final entry in value.entries) {
      final v = entry.value;
      if (v is Map<String, dynamic>) {
        out.add(_parseOne({'messageId': entry.key, ...v}, myUid: myUid));
      }
    }
    out.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return out;
  }

  ChatMessage _parseOne(Map<String, dynamic> json, {required String myUid}) {
    final senderId = json['senderId']?.toString() ?? '';
    final ms = json['timestamp'];
    return ChatMessage(
      id: json['messageId']?.toString() ?? json['id']?.toString() ?? '',
      senderId: senderId,
      senderName: senderId == myUid ? 'You' : '',
      text: json['text']?.toString() ?? '',
      sentAt: ms is num
          ? DateTime.fromMillisecondsSinceEpoch(ms.toInt())
          : DateTime.now(),
      isMine: senderId == myUid && senderId.isNotEmpty,
    );
  }
}
