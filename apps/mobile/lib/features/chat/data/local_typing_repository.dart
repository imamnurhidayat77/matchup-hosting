import 'dart:async';

import 'typing_repository.dart';

/// Offline-only typing store. Reads return empty, writes are
/// no-ops. Typing state only ever comes from the live backend.
class LocalTypingRepository implements TypingRepository {
  @override
  Future<void> setTyping({
    required String activityId,
    required bool isTyping,
  }) async {}

  @override
  Future<bool?> isTyping({
    required String activityId,
    required String uid,
  }) async {
    return null;
  }

  @override
  Stream<Set<String>> watchTyping({
    required String activityId,
    required List<String> uids,
  }) async* {
    yield const <String>{};
  }
}
