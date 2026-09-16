import '../domain/app_notification.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> all();
  Future<List<AppNotification>> unread();

  /// Marks one notification read. Returns `true` on success, `false`
  /// on transport failure (the screen shows an error and keeps the row
  /// instead of a snap-back refetch surprise).
  Future<bool> markRead(String id);

  /// Marks everything read. Returns `false` when any part of the
  /// fan-out failed so the screen can say so.
  Future<bool> markAllRead();
}
