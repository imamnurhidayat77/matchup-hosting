import '../domain/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatMessage>> messages(String activityId);
  Future<ChatMessage> send({required String activityId, required String text});
  Future<List<ChatConversation>> conversations();
}
