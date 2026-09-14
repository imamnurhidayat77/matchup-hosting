/// Domain model for a notification entry shown in the notifications feed.
class AppNotification {
  final String id;
  final String title;
  final String? body;
  final DateTime createdAt;
  final NotificationType type;
  final bool unread;

  /// Related activity, when the notification is about one. Required for
  /// deep-linking the tap to the right screen (see `routeForNotification`).
  final String? activityId;

  /// Sender of a 1-on-1 message — the DM thread peer.
  final String? senderUid;

  /// Raw backend type string (e.g. `join_request`, `dm_message`).
  /// The display [type] lumps several backend types together, but routing
  /// needs the exact one — `activity_joined` and `join_request` go to
  /// different screens despite sharing [NotificationType.request].
  final String backendType;

  const AppNotification({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.type,
    this.body,
    this.unread = false,
    this.activityId,
    this.senderUid,
    this.backendType = 'system',
  });
}

enum NotificationType { chat, activity, system, request, moderation }
