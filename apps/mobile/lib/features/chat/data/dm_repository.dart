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
///
/// Inbox rows reuse [ChatConversation] (`id` = peer uid, `isGroup` =
/// false) so the messages screen renders them with the same cards.
abstract class DmRepository {
  Stream<List<ChatMessage>> watchMessages(String otherUid);
  Future<List<ChatMessage>> messages(String otherUid, {int limit = 50});
  Future<ChatMessage> send({required String otherUid, required String text});

  /// Inbox threads, newest first, with peer names + unread badges.
  Future<List<ChatConversation>> conversations();

  /// [conversations] re-emitted on every RTDB inbox change (plus HTTP
  /// polling fallback), so badges update while the inbox sits open.
  Stream<List<ChatConversation>> watchConversations();

  /// Clears the unread badge for one thread. Best-effort.
  Future<void> markRead(String otherUid);
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
  Future<List<ChatConversation>> conversations() async {
    try {
      final res = await _client.dio.get('/dm/conversations');
      final rows = apiDataList(res.data);
      return [
        for (final e in rows)
          if (e is Map<String, dynamic>) _parseThread(e),
      ];
    } catch (e, st) {
      debugPrint('[RemoteDmRepository.conversations] $e\n$st');
      return const [];
    }
  }

  @override
  Stream<List<ChatConversation>> watchConversations() async* {
    // RTDB inbox node drives refetches; the HTTP list carries the
    // enriched peer names the raw entries lack.
    try {
      await RtdbAuthService.instance.ensureSignedIn();
      final myUid = await _myUid();
      final ref = FirebaseDatabase.instance.ref('userDMs/$myUid');
      await for (final _ in ref.onValue) {
        yield await conversations();
      }
      return;
    } catch (e, st) {
      debugPrint('[RemoteDmRepository.watchConversations] RTDB failed: $e\n$st');
    }
    while (true) {
      yield await conversations();
      await Future<void>.delayed(const Duration(seconds: 10));
    }
  }

  @override
  Future<void> markRead(String otherUid) async {
    try {
      await _client.dio.post('/dm/$otherUid/read');
    } catch (e, st) {
      debugPrint('[RemoteDmRepository.markRead] $e\n$st');
    }
  }

  ChatConversation _parseThread(Map<String, dynamic> json) {
    final peerUid = json['peerUid']?.toString() ?? '';
    final displayName = json['displayName']?.toString().trim() ?? '';
    final ms = json['lastTimestamp'];
    final sentAt = ms is num
        ? DateTime.fromMillisecondsSinceEpoch(ms.toInt())
        : null;
    return ChatConversation(
      id: peerUid,
      name: displayName.isNotEmpty ? displayName : peerUid,
      lastMessage: json['lastText']?.toString() ?? '',
      time: sentAt == null ? '' : _relativeTime(sentAt),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  String _relativeTime(DateTime sentAt) {
    final diff = DateTime.now().difference(sentAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
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

  List<ChatMessage> _parseList(Object? value, {required String myUid}) =>
      parseRtdbDmMessages(value, myUid: myUid);

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

/// Parses an RTDB `dmChats/{pair}/messages` snapshot value into
/// time-sorted messages.
///
/// Top-level (not a method) so unit tests can feed it realistic
/// snapshot shapes. CRITICAL: RTDB decodes to `Map<dynamic, dynamic>`,
/// so this must never narrow with `is Map<String, dynamic>` — generic
/// invariance would silently drop every message (thread renders empty
/// forever while the HTTP-fed inbox looks fine).
List<ChatMessage> parseRtdbDmMessages(Object? value, {required String myUid}) {
  if (value is! Map) return const [];
  final out = <ChatMessage>[];
  for (final entry in value.entries.whereType<MapEntry<dynamic, dynamic>>()) {
    final v = entry.value;
    if (v is Map) {
      final json = <String, dynamic>{
        'messageId': entry.key.toString(),
        ...Map<String, dynamic>.from(v),
      };
      out.add(_parseDmMessage(json, myUid: myUid));
    }
  }
  out.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  return out;
}

ChatMessage _parseDmMessage(Map<String, dynamic> json, {required String myUid}) {
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
