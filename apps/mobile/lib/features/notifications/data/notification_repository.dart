import '../domain/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> all();
  Future<List<AppNotification>> unread();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}
