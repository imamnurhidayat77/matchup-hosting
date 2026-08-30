import '../domain/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> messages(String activityId);
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
