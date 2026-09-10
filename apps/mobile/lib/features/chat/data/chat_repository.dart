import '../domain/chat_message.dart';

abstract class ChatRepository {
  /// One-shot fetch of all messages in [activityId]. Prefer [watchMessages]
  /// for the chat screen — it's the real-time variant that subscribes to
  /// the backend's RTDB stream (or falls back to polling).
  Future<List<ChatMessage>> messages(String activityId);

  /// Real-time stream of messages for [activityId]. Emits the current
  /// list whenever it changes (new message, edit, deletion). The stream
  /// is broadcast — multiple subscribers share one upstream connection.
  Stream<List<ChatMessage>> watchMessages(String activityId);

  Future<ChatMessage> send({required String activityId, required String text});

  /// Sends a photo attachment. [imagePath] is the local file path produced
  /// by the image picker; a remote implementation is responsible for
  /// uploading the bytes and returning a message that carries the resolved
  /// (possibly remote) path.
  Future<ChatMessage> sendImage({
    required String activityId,
    required String imagePath,
  });

  /// Shares the sender's current location as a message.
  Future<ChatMessage> sendLocation({
    required String activityId,
    required double latitude,
    required double longitude,
  });

  Future<List<ChatConversation>> conversations();
}
