import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/app_notification.dart';
import 'notification_repository.dart';

class LocalNotificationRepository implements NotificationRepository {
  final List<AppNotification> _all = [
    AppNotification(
      id: '1',
      title: 'Sarah Chen',
      body: 'I brought extra tennis balls!',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      type: NotificationType.chat,
      unread: true,
    ),
    AppNotification(
      id: '2',
      title: 'Weekend Soccer Match starting in 2 hours',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      type: NotificationType.activity,
      unread: true,
    ),
    AppNotification(
      id: '3',
      title: 'Welcome to MatchUp!',
      body: 'Start by setting your preferences',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      type: NotificationType.system,
    ),
    AppNotification(
      id: '4',
      title: 'Alex wants to join your basketball game',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.request,
    ),
    AppNotification(
      id: '5',
      title: 'Your report was resolved',
      body: 'The reported activity has been removed',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.moderation,
    ),
    AppNotification(
      id: '6',
      title: 'Mike tagged you in a volleyball match',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      type: NotificationType.activity,
    ),
    AppNotification(
      id: '7',
      title: 'New activity near you',
      body: 'Sunset Basketball 5v5 in Brooklyn',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      type: NotificationType.activity,
    ),
  ];

  @override
  Future<List<AppNotification>> all() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_all);
  }

  @override
  Future<List<AppNotification>> unread() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List.unmodifiable(_all.where((n) => n.unread));
  }

  @override
  Future<void> markRead(String id) async {
    final i = _all.indexWhere((n) => n.id == id);
    if (i >= 0) {
      _all[i] = AppNotification(
        id: _all[i].id,
        title: _all[i].title,
        body: _all[i].body,
        createdAt: _all[i].createdAt,
        type: _all[i].type,
        unread: false,
      );
    }
  }

  @override
  Future<void> markAllRead() async {
    for (var i = 0; i < _all.length; i++) {
      _all[i] = AppNotification(
        id: _all[i].id,
        title: _all[i].title,
        body: _all[i].body,
        createdAt: _all[i].createdAt,
        type: _all[i].type,
        unread: false,
      );
    }
  }
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
      final res = await _client.dio.get('/notifications');
      return (res.data as List).map(_parse).toList();
    } catch (e, st) {
      debugPrint('[RemoteNotificationRepository] $e\n$st');
      return _fallback.all();
    }
  }

  @override
  Future<List<AppNotification>> unread() async {
    try {
      final res = await _client.dio.get('/notifications/unread');
      return (res.data as List).map(_parse).toList();
    } catch (e, st) {
      debugPrint('[RemoteNotificationRepository] $e\n$st');
      return _fallback.unread();
    }
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _client.dio.post('/notifications/$id/read');
    } catch (e, st) {
      debugPrint('[RemoteNotificationRepository] $e\n$st');
      await _fallback.markRead(id);
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await _client.dio.post('/notifications/read-all');
    } catch (e, st) {
      debugPrint('[RemoteNotificationRepository] $e\n$st');
      await _fallback.markAllRead();
    }
  }

  AppNotification _parse(dynamic raw) {
    final json = raw as Map<String, dynamic>;
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      type: _typeFromString(json['type'] as String? ?? 'system'),
      unread: json['unread'] as bool? ?? false,
    );
  }

  NotificationType _typeFromString(String s) {
    switch (s) {
      case 'chat':
        return NotificationType.chat;
      case 'activity':
        return NotificationType.activity;
      case 'request':
        return NotificationType.request;
      case 'moderation':
        return NotificationType.moderation;
      default:
        return NotificationType.system;
    }
  }
}
