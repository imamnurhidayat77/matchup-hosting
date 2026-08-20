/// Domain model for a single chat message inside an activity group chat.
class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarAsset;
  final String text;
  final DateTime sentAt;
  final bool isMine;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    this.senderAvatarAsset,
    this.isMine = false,
  });
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
