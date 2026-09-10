import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'local_typing_repository.dart';
import 'typing_repository.dart';

/// HTTP-backed [TypingRepository] for the live MatchUp API.
///
/// Endpoints used:
///   - `POST /api/typing`                       — set current user's state
///   - `GET  /api/typing/:activityId/:uid`      — fetch a user's state
///
/// Writes are fire-and-forget — a typing indicator that's a few hundred
/// milliseconds late is harmless, and a flaky network shouldn't block
/// the user's keystroke. Reads treat 404 as "not typing" rather than an
/// error so the chat header doesn't flicker on a missing row.
class RemoteTypingRepository implements TypingRepository {
  RemoteTypingRepository({
    ApiClient? client,
    TypingRepository? fallback,
  })  : _client = client ?? ApiClient.instance,
        _fallback = fallback ?? LocalTypingRepository();

  final ApiClient _client;
  final TypingRepository _fallback;

  /// Cadence for [watchTyping]. Typing indicators feel live at
  /// ~2s — fast enough to be perceptible, slow enough that even a
  /// group of 20 participants only generates 10 RPS of background
  /// traffic.
  static const Duration _typingPollInterval = Duration(seconds: 2);

  @override
  Future<void> setTyping({
    required String activityId,
    required bool isTyping,
  }) async {
    try {
      await _client.dio.post(
        '/typing',
        data: {
          'activityId': activityId,
          'isTyping': isTyping,
        },
      );
    } catch (e, st) {
      debugPrint('[RemoteTypingRepository.setTyping] $e\n$st');
      await _fallback.setTyping(activityId: activityId, isTyping: isTyping);
    }
  }

  @override
  Future<bool?> isTyping({
    required String activityId,
    required String uid,
  }) async {
    try {
      final res = await _client.dio.get('/typing/$activityId/$uid');
      // Response shape: { ok, data: { activityId, uid, isTyping } }.
      final data = apiDataMap(res.data);
      if (data == null) return null;
      return data['isTyping'] as bool?;
    } on Exception catch (e) {
      // 404 = user hasn't typed since the activity started. Treat as
      // "not typing" so the chat header doesn't flash an error.
      if (!e.toString().contains('404')) {
        debugPrint('[RemoteTypingRepository.isTyping] $e');
      }
      return _fallback.isTyping(activityId: activityId, uid: uid);
    }
  }

  @override
  Stream<Set<String>> watchTyping({
    required String activityId,
    required List<String> uids,
  }) async* {
    if (uids.isEmpty) {
      yield const <String>{};
      return;
    }

    final controller = StreamController<Set<String>>();
    Timer? timer;

    Future<void> tick() async {
      // Fan out a typing-status request per uid. Individual failures
      // are swallowed (treat as "not typing") so one slow network
      // call doesn't block the rest of the roster.
      final results = await Future.wait(
        uids.map((uid) async {
          try {
            // Use the same backing call as the public isTyping() but
            // route through a local alias to avoid the name clash
            // with the `isTyping` field below.
            final status = await _isTypingOnce(
              activityId: activityId,
              uid: uid,
            );
            return MapEntry(uid, status == true);
          } catch (_) {
            return MapEntry(uid, false);
          }
        }),
      );
      final typing = <String>{
        for (final entry in results)
          if (entry.value) entry.key,
      };
      if (!controller.isClosed) controller.add(typing);
    }

    // Emit immediately, then on every interval tick.
    unawaited(tick());
    timer = Timer.periodic(_typingPollInterval, (_) => tick());

    controller.onCancel = () {
      timer?.cancel();
      timer = null;
    };

    yield* controller.stream;
  }

  /// Same as [isTyping] but with a different name so it can be
  /// called from inside the closure of [watchTyping] without
  /// shadowing. Kept private — external callers should use
  /// [isTyping].
  Future<bool?> _isTypingOnce({
    required String activityId,
    required String uid,
  }) {
    return isTyping(activityId: activityId, uid: uid);
  }
}
