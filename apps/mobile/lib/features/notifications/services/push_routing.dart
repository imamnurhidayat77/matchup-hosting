// Payload carried by an FCM data message, mirrored from the backend's
// `deliverPush` (`data: {type, activityId?}`). Pure parsing + routing
// lives here so it is unit-testable without Firebase or widgets.
import '../domain/app_notification.dart';

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

/// SharedPreferences key for the locally muted group-chat ids
/// (string list of activity ids). Mute is local-only (no backend
/// support): the chat settings sheet toggles it, the foreground push
/// banner skips muted chats.
const mutedChatsKey = 'muted_chats';

/// True when a push of this type can change My Games membership —
/// cancelled/completed/removed games leave Upcoming, joins/requests/
/// removals enter or move rows. The app shell invalidates the My Games
/// tab providers on these pushes so a cancelled game vanishes without
/// a manual pull-to-refresh (lists render stale-while-revalidate, so
/// there is no skeleton flash). Chat/system pushes never qualify.
bool invalidatesMyGames(PushPayload payload) {
  return switch (payload.type) {
    'activity_cancelled' ||
    'activity_completed' ||
    'activity_joined' ||
    'activity_left' ||
    'participant_removed' ||
    'join_request' =>
      true,
    _ => false,
  };
}

/// Deep-link route for a parsed payload, or null when the payload has
/// no usable target (unknown type). Callers must no-op (or snackbar)
/// on null instead of pushing the notifications feed — dropping the
/// user on the feed for a tap they already sit on is a navigation
/// surprise, not a recovery.
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
      // Unknown type — no honest target. The caller no-ops.
      return null;
  }
}

/// Deep-link route for a feed notification, reusing the push table so
/// tray taps and feed taps always agree. Returns null when the row has
/// no usable target (unknown backend type) — the feed stays put (it is
/// already showing, so staying is the honest default).
String? routeForNotification(AppNotification notif) {
  return routeForPush(
    PushPayload(
      type: notif.backendType,
      activityId: notif.activityId,
      senderUid: notif.senderUid,
    ),
  );
}
