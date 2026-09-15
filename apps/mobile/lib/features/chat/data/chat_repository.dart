import '../domain/chat_message.dart';
import '../domain/chat_poll.dart';
import '../domain/chat_reaction.dart';

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

  /// Real-time stream of emoji reactions for [activityId], keyed by
  /// message id (`messageId → emoji → uids`). Same broadcast contract
  /// as [watchMessages].
  Stream<MessageReactions> watchReactions(String activityId);

  /// Toggles the current user's [emoji] reaction on one message.
  /// Returns `true` when the reaction was added, `false` when it was
  /// removed, `null` when the request failed.
  Future<bool?> toggleReaction({
    required String activityId,
    required String messageId,
    required String emoji,
  });

  /// Real-time stream of single-choice polls for [activityId],
  /// oldest first. Same broadcast contract as [watchMessages].
  Stream<List<ChatPoll>> watchPolls(String activityId);

  /// Creates a poll with [question] and 2–6 [options].
  /// Returns the new poll id, or `null` when the request failed.
  Future<String?> createPoll({
    required String activityId,
    required String question,
    required List<String> options,
  });

  /// Votes for [optionIndex] (single-choice; voting the same option
  /// again retracts the vote). Returns the server's `voted` flag,
  /// or `null` when the request failed.
  Future<bool?> votePoll({
    required String activityId,
    required String pollId,
    required int optionIndex,
  });

  Future<List<ChatConversation>> conversations();
}
