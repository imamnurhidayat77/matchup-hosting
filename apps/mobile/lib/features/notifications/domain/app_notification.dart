/// Domain model for a notification entry shown in the notifications feed.
class AppNotification {
  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;
  final NotificationType type;
  final bool unread;

  const AppNotification({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.type,
    this.body,
    this.unread = false,
  });
}

enum NotificationType { chat, activity, system, request, moderation }
