import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/chat_message.dart';
import 'chat_repository.dart';

class DummyChatRepository implements ChatRepository {
  final Map<String, List<ChatMessage>> _byActivity = {};

  List<ChatMessage> _seed(String activityId) {
    final base = DateTime.now();
    return [
      ChatMessage(
        id: '$activityId-1',
        senderId: 'alex',
        senderName: 'Alex Mercer',
        senderAvatarAsset: 'assets/images/discovery/avatars/avatar_alex.png',
        text: 'Hey everyone! Excited for the match tomorrow!',
        sentAt: base.subtract(const Duration(minutes: 35)),
      ),
      ChatMessage(
        id: '$activityId-2',
        senderId: 'me',
        senderName: 'You',
        text: 'Same here! Should we bring extra balls?',
        sentAt: base.subtract(const Duration(minutes: 33)),
        isMine: true,
      ),
      ChatMessage(
        id: '$activityId-3',
        senderId: 'sarah',
        senderName: 'Sarah Chen',
        senderAvatarAsset: 'assets/images/discovery/avatars/sarah_c.png',
        text: 'I can bring 2 extra ones.',
        sentAt: base.subtract(const Duration(minutes: 32)),
      ),
      ChatMessage(
        id: '$activityId-4',
        senderId: 'jake',
        senderName: 'Jake Wilson',
        senderAvatarAsset: 'assets/images/discovery/avatars/avatar_alex.png',
        text: 'Perfect, see you all at 4pm!',
        sentAt: base.subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> messages(String activityId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(
      _byActivity.putIfAbsent(activityId, () => _seed(activityId)),
    );
  }

  @override
  Future<ChatMessage> send({
    required String activityId,
    required String text,
  }) async {
    final msg = ChatMessage(
      id: '$activityId-${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      senderName: 'You',
      text: text,
      sentAt: DateTime.now(),
      isMine: true,
    );
    _byActivity.putIfAbsent(activityId, () => _seed(activityId)).add(msg);
    return msg;
  }

  @override
  Future<ChatMessage> sendImage({
    required String activityId,
    required String imagePath,
  }) async {
    final msg = ChatMessage(
      id: '$activityId-${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      senderName: 'You',
      text: '',
      sentAt: DateTime.now(),
      isMine: true,
      imagePath: imagePath,
    );
    _byActivity.putIfAbsent(activityId, () => _seed(activityId)).add(msg);
    return msg;
  }

  @override
  Future<ChatMessage> sendLocation({
    required String activityId,
    required double latitude,
    required double longitude,
  }) async {
    final msg = ChatMessage(
      id: '$activityId-${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'me',
      senderName: 'You',
      text: '',
      sentAt: DateTime.now(),
      isMine: true,
      latitude: latitude,
      longitude: longitude,
    );
    _byActivity.putIfAbsent(activityId, () => _seed(activityId)).add(msg);
    return msg;
  }

  @override
  Future<List<ChatConversation>> conversations() async {
    await Future.delayed(const Duration(milliseconds: 80));
    return const [
      ChatConversation(
        id: '1',
        name: 'Friendly 5v5 Basketball',
        lastMessage: "Alex: I'm bringing the bas...",
        time: '2m ago',
        unreadCount: 3,
        isGroup: true,
        avatarAsset: 'assets/images/discovery/covers/basketball_full.png',
      ),
      ChatConversation(
        id: '2',
        name: 'Marcus Vance (Tennis)',
        lastMessage: "Sure, let's play on Court #2 inste...",
        time: 'Yesterday',
        unreadCount: 0,
        isGroup: false,
        avatarAsset: 'assets/images/discovery/avatars/avatar_1.png',
      ),
      ChatConversation(
        id: '3',
        name: 'Weekend Trail Run',
        lastMessage: 'Sara: Weather looks great for Su...',
        time: '3 days ago',
        unreadCount: 0,
        isGroup: true,
        avatarAsset: 'assets/images/discovery/avatars/avatar_2.png',
      ),
    ];
  }
}

class RemoteChatRepository implements ChatRepository {
  RemoteChatRepository({ApiClient? client, ChatRepository? fallback})
    : _client = client ?? ApiClient.instance,
      _fallback = fallback ?? DummyChatRepository();

  final ApiClient _client;
  final ChatRepository _fallback;

  @override
  Future<List<ChatMessage>> messages(String activityId) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/activities/$activityId/messages',
      );
      return (res.data as List)
          .map((e) => _parse(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('[RemoteChatRepository] $e\n$st');
      return _fallback.messages(activityId);
    }
  }

  @override
  Future<ChatMessage> send({
    required String activityId,
    required String text,
  }) async {
    try {
      final res = await _client.dio.post(
        '/api/v1/activities/$activityId/messages',
        data: {'text': text},
      );
      return _parse(res.data as Map<String, dynamic>);
    } catch (e, st) {
      debugPrint('[RemoteChatRepository] $e\n$st');
      return _fallback.send(activityId: activityId, text: text);
    }
  }

  @override
  Future<ChatMessage> sendImage({
    required String activityId,
    required String imagePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath),
      });
      final res = await _client.dio.post(
        '/api/v1/activities/$activityId/messages/image',
        data: formData,
      );
      return _parse(res.data as Map<String, dynamic>);
    } catch (e, st) {
      debugPrint('[RemoteChatRepository] $e\n$st');
      return _fallback.sendImage(activityId: activityId, imagePath: imagePath);
    }
  }

  @override
  Future<ChatMessage> sendLocation({
    required String activityId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final res = await _client.dio.post(
        '/api/v1/activities/$activityId/messages/location',
        data: {'latitude': latitude, 'longitude': longitude},
      );
      return _parse(res.data as Map<String, dynamic>);
    } catch (e, st) {
      debugPrint('[RemoteChatRepository] $e\n$st');
      return _fallback.sendLocation(
        activityId: activityId,
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  @override
  Future<List<ChatConversation>> conversations() async {
    try {
      final res = await _client.dio.get('/api/v1/conversations');
      return (res.data as List)
          .map((e) => _parseConversation(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('[RemoteChatRepository] $e\n$st');
      return _fallback.conversations();
    }
  }

  ChatConversation _parseConversation(Map<String, dynamic> json) =>
      ChatConversation(
        id: json['id']?.toString() ?? '',
        name: json['name'] as String? ?? '',
        lastMessage: json['last_message'] as String? ?? '',
        time: json['time'] as String? ?? '',
        unreadCount: json['unread_count'] as int? ?? 0,
        isGroup: json['is_group'] as bool? ?? false,
        avatarAsset: json['avatar_asset'] as String?,
      );

  ChatMessage _parse(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '',
    senderId: json['sender_id']?.toString() ?? '',
    senderName: json['sender_name'] as String? ?? '',
    senderAvatarAsset: json['sender_avatar'] as String?,
    text: json['text'] as String? ?? '',
    sentAt:
        DateTime.tryParse(json['sent_at'] as String? ?? '') ?? DateTime.now(),
    isMine: json['is_mine'] as bool? ?? false,
    imagePath: json['image_path'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}
