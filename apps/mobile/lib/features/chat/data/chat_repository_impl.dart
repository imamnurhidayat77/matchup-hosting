import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/rtdb_auth_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../discovery/data/remote_activity_repository.dart';
import '../domain/chat_message.dart';
import 'chat_repository.dart';

class LocalChatRepository implements ChatRepository {
  /// Offline-only chat store. Reads return empty results, writes
  /// throw. The app **always** talks to the live backend for chat.
  @override
  Future<List<ChatMessage>> messages(String activityId) async {
    return const <ChatMessage>[];
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String activityId) async* {
    yield const <ChatMessage>[];
  }

  @override
  Future<ChatMessage> send({
    required String activityId,
    required String text,
  }) async {
    throw StateError(
      'ChatRepository.send() requires a live backend — no offline '
      'fallback is provided.',
    );
  }

  @override
  Future<ChatMessage> sendImage({
    required String activityId,
    required String imagePath,
  }) async {
    throw StateError(
      'ChatRepository.sendImage() requires a live backend — no offline '
      'fallback is provided.',
    );
  }

  @override
  Future<ChatMessage> sendLocation({
    required String activityId,
    required double latitude,
    required double longitude,
  }) async {
    throw StateError(
      'ChatRepository.sendLocation() requires a live backend — no '
      'offline fallback is provided.',
    );
  }

  @override
  Future<List<ChatConversation>> conversations() async {
    return const <ChatConversation>[];
  }
}

class RemoteChatRepository implements ChatRepository {
  RemoteChatRepository({
    ApiClient? client,
    ChatRepository? fallback,
    RemoteActivityRepository? activities,
  })  : _client = client ?? ApiClient.instance,
        _fallback = fallback ?? LocalChatRepository(),
        _activities = activities ?? RemoteActivityRepository();

  final ApiClient _client;
  final ChatRepository _fallback;
  final RemoteActivityRepository _activities;

  /// Polling interval for the HTTP fallback. RTDB is preferred when
  /// available — 3 seconds is the next best thing for chat-feel.
  static const Duration _pollingInterval = Duration(seconds: 3);

  /// uid → sender profile cache per activity, so chat bubbles show names
  /// and avatars without an N+1 profile lookup on every poll tick.
  /// Refreshed at most once a minute per activity.
  final Map<String, _SenderCache> _senderCache = {};

  @override
  Future<List<ChatMessage>> messages(String activityId) async {
    try {
      final res = await _client.dio.get('/chat/$activityId/messages');
      final myUid = await SecureTokenStore.instance.readUserId() ?? '';
      final senders = await _senderProfiles(activityId);
      return apiDataList(res.data)
          .whereType<Map<String, dynamic>>()
          .map((m) => _parse(m, myUid: myUid, senders: senders))
          .whereType<ChatMessage>()
          .toList();
    } catch (e, st) {
      debugPrint('[RemoteChatRepository.messages] $e\n$st');
      return _fallback.messages(activityId);
    }
  }

  /// Resolves sender uids to display names + avatar URLs via the
  /// activity roster. Falls back to raw uids when the roster is
  /// unreachable.
  Future<Map<String, _SenderProfile>> _senderProfiles(
    String activityId,
  ) async {
    final cached = _senderCache[activityId];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(minutes: 1)) {
      return cached.senders;
    }
    try {
      final roster = await _activities.participants(activityId);
      final senders = <String, _SenderProfile>{
        for (final p in roster)
          p.userId: _SenderProfile(name: p.name, avatarUrl: p.avatarUrl),
      };
      _senderCache[activityId] = _SenderCache(senders, DateTime.now());
      return senders;
    } catch (_) {
      return const {};
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String activityId) async* {
    // Try the RTDB-backed real-time path first. Falls back to HTTP
    // polling if Firebase isn't initialised (no google-services.json /
    // GoogleService-Info.plist) or if the RTDB listener errors.
    if (_isFirebaseReady()) {
      try {
        // Make sure the SDK session exists before subscribing — an
        // anonymous listener gets permission-denied under the RTDB
        // rules and would permanently fall back to polling for this
        // screen session.
        await RtdbAuthService.instance.ensureSignedIn();
        final myUid = await SecureTokenStore.instance.readUserId() ?? '';
        final senders = await _senderProfiles(activityId);
        await for (final messages in _watchViaRtdb(
          activityId,
          myUid: myUid,
          senders: senders,
        )) {
          yield messages;
        }
        return;
      } catch (e, st) {
        debugPrint(
          '[RemoteChatRepository.watchMessages] RTDB failed, '
          'falling back to polling: $e\n$st',
        );
      }
    }
    yield* _watchViaPolling(activityId);
  }

  /// Real-time path: subscribe to `activityChats/{activityId}/messages`
  /// in the Firebase Realtime Database. Emits a fresh list each time
  /// the snapshot changes (new message, edit, delete).
  Stream<List<ChatMessage>> _watchViaRtdb(
    String activityId, {
    required String myUid,
    required Map<String, _SenderProfile> senders,
  }) {
    final ref = FirebaseDatabase.instance.ref(
      'activityChats/$activityId/messages',
    );
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <ChatMessage>[];
      final messages = value.entries
          .whereType<MapEntry<dynamic, dynamic>>()
          .map(
            (e) => _parseRtdbMessage(
              e.key.toString(),
              e.value,
              myUid: myUid,
              senders: senders,
            ),
          )
          .whereType<ChatMessage>()
          .toList()
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      return messages;
    });
  }

  /// Polling fallback. Hits the HTTP `/activities/:id/messages` endpoint
  /// every [_pollingInterval] and emits the latest list. Less efficient
  /// than RTDB but works without any Firebase config.
  Stream<List<ChatMessage>> _watchViaPolling(String activityId) async* {
    final controller = StreamController<List<ChatMessage>>();
    Timer? timer;

    Future<void> tick() async {
      try {
        final latest = await messages(activityId);
        if (!controller.isClosed) controller.add(latest);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    // Emit immediately, then on each tick.
    unawaited(tick());
    timer = Timer.periodic(_pollingInterval, (_) => tick());

    controller.onCancel = () {
      timer?.cancel();
      timer = null;
    };

    yield* controller.stream;
  }

  /// Parses a single RTDB message entry. The backend writes messages
  /// with this shape (per the chat service):
  ///   { senderId: string, text: string, type: 'text' | 'system',
  ///     timestamp: number (epoch millis) }
  ChatMessage? _parseRtdbMessage(
    String id,
    dynamic raw, {
    required String myUid,
    required Map<String, _SenderProfile> senders,
  }) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final senderId = json['senderId']?.toString() ?? '';
    final text = json['text'] as String? ?? '';
    if (senderId.isEmpty || text.isEmpty) return null;
    final isMine = myUid.isNotEmpty && senderId == myUid;
    final sender = senders[senderId];
    return ChatMessage(
      id: id,
      senderId: senderId,
      senderName: isMine ? 'You' : (sender?.name ?? senderId),
      senderAvatarUrl: isMine ? null : sender?.avatarUrl,
      text: text,
      sentAt: _parseTimestamp(json['timestamp']) ?? DateTime.now(),
      isMine: isMine,
    );
  }

  /// Coerces a Firestore / RTDB timestamp (ISO string, epoch number, or
  /// `{ seconds, nanoseconds }` map) into a [DateTime].
  DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is num) {
      // Server timestamps are typically epoch seconds, but Firebase JS
      // SDKs sometimes serialise as milliseconds. Heuristic: anything
      // smaller than 10^11 is treated as seconds.
      final ms = raw.toInt() < 100000000000 ? raw.toInt() * 1000 : raw.toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (raw is Map) {
      final seconds = raw['seconds'] ?? raw['_seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
      }
    }
    return null;
  }

  /// True if Firebase has been initialised (i.e. `Firebase.initializeApp()`
  /// succeeded at app start). When false, the real-time path is skipped
  /// and the polling fallback is used.
  bool _isFirebaseReady() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ChatMessage> send({
    required String activityId,
    required String text,
  }) async {
    try {
      // Canonical route is `POST /api/chat/messages` with the activity
      // id in the body. The response carries `{messageId}` only, so the
      // bubble is constructed locally (sender = me).
      final res = await _client.dio.post(
        '/chat/messages',
        data: {'activityId': activityId, 'text': text},
      );
      final messageId =
          apiDataMap(res.data)?['messageId']?.toString() ??
              '$activityId-${DateTime.now().millisecondsSinceEpoch}';
      final myUid = await SecureTokenStore.instance.readUserId() ?? '';
      return ChatMessage(
        id: messageId,
        senderId: myUid,
        senderName: 'You',
        text: text,
        sentAt: DateTime.now(),
        isMine: true,
      );
    } catch (e, st) {
      debugPrint('[RemoteChatRepository.send] $e\n$st');
      return _fallback.send(activityId: activityId, text: text);
    }
  }

  @override
  Future<ChatMessage> sendImage({
    required String activityId,
    required String imagePath,
  }) async {
    // The backend stores text-only messages, so an image is shared by
    // uploading to Firebase Storage first and posting the download URL
    // as the message text. The local bubble keeps `imagePath` so the
    // photo renders inline immediately.
    try {
      final uploadedUrl = await StorageService.instance.uploadImage(
        localPath: imagePath,
        folder: 'chat-attachments/$activityId',
      );
      if (uploadedUrl == null) {
        return await _fallback.sendImage(
          activityId: activityId,
          imagePath: imagePath,
        );
      }
      final sent = await send(activityId: activityId, text: uploadedUrl);
      return ChatMessage(
        id: sent.id,
        senderId: sent.senderId,
        senderName: sent.senderName,
        text: sent.text,
        sentAt: sent.sentAt,
        isMine: true,
        imagePath: imagePath,
      );
    } catch (e, st) {
      debugPrint('[RemoteChatRepository.sendImage] $e\n$st');
      return _fallback.sendImage(activityId: activityId, imagePath: imagePath);
    }
  }

  @override
  Future<ChatMessage> sendLocation({
    required String activityId,
    required double latitude,
    required double longitude,
  }) async {
    // Same text-only constraint as images: the coordinates travel as a
    // maps link inside a regular message. The local bubble keeps the
    // raw coordinates so the map preview renders immediately.
    try {
      final sent = await send(
        activityId: activityId,
        text: '📍 Shared location: https://maps.google.com/?q=$latitude,$longitude',
      );
      return ChatMessage(
        id: sent.id,
        senderId: sent.senderId,
        senderName: sent.senderName,
        text: sent.text,
        sentAt: sent.sentAt,
        isMine: true,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e, st) {
      debugPrint('[RemoteChatRepository.sendLocation] $e\n$st');
      return _fallback.sendLocation(
        activityId: activityId,
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  @override
  Future<List<ChatConversation>> conversations() async {
    // No dedicated backend route — the inbox is derived from the
    // activities feed (viewer context flags mark what the user joined
    // or hosts) plus the latest message of each, best-effort.
    try {
      final activities = await _activities.feed(limit: 50, filter: null);
      final mine =
          activities.where((a) => a.isParticipant || a.isHost).toList();
      final entries = await Future.wait(
        mine.map((activity) async {
          String lastMessage = '';
          String time = '';
          try {
            final msgs = await messages(activity.id);
            if (msgs.isNotEmpty) {
              final last = msgs.last;
              final who = last.isMine ? 'You' : last.senderName;
              lastMessage =
                  last.text.length > 60 ? '${last.text.substring(0, 60)}…' : last.text;
              lastMessage = '$who: $lastMessage';
              time = _relativeTime(last.sentAt);
            }
          } catch (_) {
            // One broken thread must not sink the whole inbox.
          }
          return ChatConversation(
            id: activity.id,
            name: activity.title,
            lastMessage: lastMessage,
            time: time,
            unreadCount: 0,
            isGroup: true,
          );
        }),
      );
      return entries;
    } catch (e, st) {
      debugPrint('[RemoteChatRepository.conversations] $e\n$st');
      return _fallback.conversations();
    }
  }

  /// Compact relative timestamp for the inbox rows
  /// (`2m ago`, `3h ago`, `Yesterday`, `4d ago`).
  String _relativeTime(DateTime sentAt) {
    final diff = DateTime.now().difference(sentAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  /// Parses one backend chat message:
  /// `{messageId, senderId, text, type, timestamp}`.
  ChatMessage? _parse(
    Map<String, dynamic> json, {
    required String myUid,
    required Map<String, _SenderProfile> senders,
  }) {
    final senderId = json['senderId']?.toString() ?? '';
    final text = json['text'] as String? ?? '';
    if (senderId.isEmpty || text.isEmpty) return null;
    final isMine = myUid.isNotEmpty && senderId == myUid;
    final sender = senders[senderId];
    return ChatMessage(
      id: json['messageId']?.toString() ?? json['id']?.toString() ?? '',
      senderId: senderId,
      senderName: isMine ? 'You' : (sender?.name ?? senderId),
      senderAvatarUrl: isMine ? null : sender?.avatarUrl,
      text: text,
      sentAt: _parseTimestamp(json['timestamp']) ?? DateTime.now(),
      isMine: isMine,
    );
  }
}

/// uid → sender profile snapshot with its fetch time, backing the
/// sender cache in [RemoteChatRepository].
class _SenderCache {
  const _SenderCache(this.senders, this.fetchedAt);
  final Map<String, _SenderProfile> senders;
  final DateTime fetchedAt;
}

/// Display name + avatar URL of one chat participant, resolved from
/// the activity roster.
class _SenderProfile {
  const _SenderProfile({required this.name, this.avatarUrl});
  final String name;
  final String? avatarUrl;
}
