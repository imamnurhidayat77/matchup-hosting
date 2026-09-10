import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/app_notification.dart';
import 'notification_repository.dart';

/// Offline-only notification store. Reads return empty, writes are
/// no-ops. Notifications only come from the live backend.
class LocalNotificationRepository implements NotificationRepository {
  @override
  Future<List<AppNotification>> all() async {
    return const <AppNotification>[];
  }

  @override
  Future<List<AppNotification>> unread() async {
    return const <AppNotification>[];
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}
}

class RemoteNotificationRepository implements NotificationRepository {
  RemoteNotificationRepository({
    ApiClient? client,
    NotificationRepository? fallback,
  }) : _client = client ?? ApiClient.instance,
       _fallback = fallback ?? LocalNotificationRepository();

  final ApiClient _client;
  final NotificationRepository _fallback;

  @override
  Future<List<AppNotification>> all() async {
    try {
      // Canonical route is `GET /api/notifications/me` (no `/unread`
      // variant exists on the backend).
      final res = await _client.dio.get('/notifications/me');
      return apiDataList(res.data).map(_parse).toList();
    } catch (e, st) {
      debugPrint('[RemoteNotificationRepository.all] $e\n$st');
      return _fallback.all();
    }
  }

  @override
  Future<List<AppNotification>> unread() async {
    try {
      final items = await all();
      return items.where((n) => n.unread).toList();
    } catch (e, st) {
      debugPrint('[RemoteNotificationRepository.unread] $e\n$st');
      return _fallback.unread();
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      // Canonical route is `PATCH /api/notifications/me/:id/read`.
      await _client.dio.patch('/notifications/me/$id/read');
    } catch (e, st) {
      debugPrint('[RemoteNotificationRepository.markRead] $e\n$st');
      await _fallback.markRead(id);
    }
  }

  @override
  Future<void> markAllRead() async {
    // No bulk endpoint on the backend — fan out per-notification.
    // Individual failures are swallowed so one bad id can't block
    // the rest.
    try {
      final pending = await unread();
      await Future.wait(
        pending.map((n) async {
          try {
            await _client.dio.patch('/notifications/me/${n.id}/read');
          } catch (_) {}
        }),
      );
    } catch (e, st) {
      debugPrint('[RemoteNotificationRepository.markAllRead] $e\n$st');
      await _fallback.markAllRead();
    }
  }

  AppNotification _parse(dynamic raw) {
    // Backend shape: `{notificationId, title, body, type, isRead,
    // createdAt: {_seconds,…}, activityId?, senderUid?}`.
    final json = raw as Map<String, dynamic>;
    return AppNotification(
      id: json['notificationId']?.toString() ??
          json['id']?.toString() ??
          '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      createdAt: _parseTimestamp(json['createdAt']) ?? DateTime.now(),
      type: _typeFromString(json['type'] as String? ?? 'system'),
      unread: !(json['isRead'] as bool? ?? true),
    );
  }

  DateTime? _parseTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is Map) {
      final seconds = raw['seconds'] ?? raw['_seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
      }
    }
    return null;
  }

  NotificationType _typeFromString(String s) {
    switch (s) {
      case 'chat' || 'chat_message':
        return NotificationType.chat;
      case 'activity' ||
            'activity_reminder' ||
            'activity_cancelled' ||
            'activity_completed' ||
            'activity_left':
        return NotificationType.activity;
      case 'request' ||
            'activity_interest' ||
            'activity_joined' ||
            'join_request':
        return NotificationType.request;
      case 'moderation' || 'participant_removed':
        return NotificationType.moderation;
      default:
        return NotificationType.system;
    }
  }
}
