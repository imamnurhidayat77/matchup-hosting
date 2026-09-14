/// Domain model for a single chat message inside an activity group chat.
///
/// A message is plain text by default. [imagePath] (set) marks it as a
/// photo attachment; [latitude]/[longitude] (both set) mark it as a shared
/// location. These are mutually exclusive in practice — [ChatRepository]
/// only ever sets one attachment kind per message — so the presentation
/// layer branches on "which field is non-null" rather than a separate enum.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarAsset;

  /// Remote photo URL of the sender (`photoUrl` on their profile), if
  /// known. Takes precedence over [senderAvatarAsset] at render time.
  final String? senderAvatarUrl;
  final String text;
  final DateTime sentAt;
  final bool isMine;

  /// Local file path of an attached photo, when this message is a photo
  /// upload rather than plain text.
  final String? imagePath;

  /// Coordinates of a shared location, when this message is a location
  /// share rather than plain text. Always set together.
  final double? latitude;
  final double? longitude;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.senderAvatarAsset,
    this.senderAvatarUrl,
    this.isMine = false,
    this.imagePath,
    this.latitude,
    this.longitude,
  });

  bool get isImage => imagePath != null;
  bool get isLocation => latitude != null && longitude != null;
}

/// Represents a conversation entry in the messages list (inbox).
class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
    this.isGroup = false,
    this.avatarAsset,
  });

  final String id;
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isGroup;
  final String? avatarAsset;
}
