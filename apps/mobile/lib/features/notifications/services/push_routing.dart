// Payload carried by an FCM data message, mirrored from the backend's
// `deliverPush` (`data: {type, activityId?}`). Pure parsing + routing
// lives here so it is unit-testable without Firebase or widgets.

class PushPayload {
  const PushPayload(
      {required this.type, this.activityId, this.senderUid, this.title});

  /// Backend notification type, e.g. `chat_message`, `activity_completed`.
  final String type;

  /// Related activity, when the notification is about one.
  final String? activityId;

  /// Sender of a 1-on-1 message — the DM thread peer.
  final String? senderUid;

  /// Human-readable title for foreground snackbars.
  final String? title;

  /// Parses an FCM `RemoteMessage.data` map (values arrive as
  /// `Map<String, dynamic>` from the plugin). Returns null when the
  /// map carries no usable type (caller should ignore the message).
  static PushPayload? parse(Map<String, dynamic> data, {String? title}) {
    final type = data['type']?.toString().trim() ?? '';
    if (type.isEmpty) return null;
    final activityId = data['activityId']?.toString().trim();
    final senderUid = data['senderUid']?.toString().trim();
    return PushPayload(
      type: type,
      activityId: activityId == null || activityId.isEmpty ? null : activityId,
      senderUid: senderUid == null || senderUid.isEmpty ? null : senderUid,
      title: title,
    );
  }
}

/// Deep-link route for a parsed payload, or null when the app should
/// just land on the notifications feed.
String? routeForPush(PushPayload payload) {
  final id = payload.activityId;
  switch (payload.type) {
    case 'chat_message':
      if (id != null) return '/chat/$id';
      return '/notifications';
    case 'dm_message':
      final peer = payload.senderUid;
      if (peer != null) return '/dm/$peer';
      return '/notifications';
    case 'activity_completed':
      if (id != null) return '/past-activity/$id/review';
      return '/notifications';
    case 'join_request':
      if (id != null) return '/manage-activity/$id';
      return '/notifications';
    case 'activity_joined':
    case 'activity_cancelled':
    case 'activity_reminder':
    case 'activity_interest':
    case 'activity_left':
    case 'participant_removed':
      if (id != null) return '/activity/$id';
      return '/notifications';
    default:
      return '/notifications';
  }
}
