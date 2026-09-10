import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_token_store.dart';
import '../domain/presence_state.dart';
import 'local_presence_repository.dart';
import 'presence_repository.dart';

/// HTTP-backed [PresenceRepository] for the live MatchUp API.
///
/// Endpoints used:
///   - `POST /api/presence`           — set current user's state
///   - `GET  /api/presence/:uid`      — fetch a user's state
///
/// All operations swallow transport errors and fall back to a no-op so
/// that a flaky network never desyncs the local UI from the user's
/// "online" badge. Additionally, every successful `online` write arms
/// an RTDB `onDisconnect` dead-man's switch that flips the user back
/// to `offline` server-side if the socket drops without a clean
/// shutdown (app kill, OS reclaim, tunnel loss) — so a missed
/// `setMyState('offline')` call is recovered within seconds.
class RemotePresenceRepository implements PresenceRepository {
  RemotePresenceRepository({
    ApiClient? client,
    PresenceRepository? fallback,
  })  : _client = client ?? ApiClient.instance,
        _fallback = fallback ?? LocalPresenceRepository();

  final ApiClient _client;
  final PresenceRepository _fallback;

  /// Cadence for [watchOnline]. The backend's presence is server-side
  /// authoritative, so a 30-second poll is plenty — the user doesn't
  /// need to know within 100ms that someone went offline.
  static const Duration _onlinePollInterval = Duration(seconds: 30);

  @override
  Future<void> setMyState(PresenceState state) async {
    try {
      await _client.dio.post(
        '/presence',
        data: {'state': state.wireValue},
      );
      if (state == PresenceState.online) {
        // Best-effort and strictly additive: if arming fails (no
        // Firebase config, no session), the explicit offline write on
        // background/quit still covers the common paths.
        await _armOfflineOnDisconnect().timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      }
    } catch (e, st) {
      debugPrint('[RemotePresenceRepository.setMyState] $e\n$st');
      // Don't fall through to the local fallback for writes — the
      // whole point of presence is server-side truth, and writing a
      // stale state to a local cache would mask the failure.
    }
  }

  /// Registers a server-side trigger that writes this user `offline`
  /// the moment their RTDB connection drops. Must be re-armed on every
  /// foreground transition because Firebase fires (and clears) it once.
  Future<void> _armOfflineOnDisconnect() async {
    try {
      if (Firebase.apps.isEmpty) return;
      final uid = await SecureTokenStore.instance.readUserId();
      if (uid == null || uid.isEmpty) return;
      await FirebaseDatabase.instance
          .ref('presence/$uid')
          .onDisconnect()
          .set({'state': 'offline', 'lastChanged': DateTime.now().millisecondsSinceEpoch});
    } catch (e) {
      debugPrint('[RemotePresenceRepository.onDisconnect] $e');
    }
  }

  @override
  Future<PresenceState?> getState(String uid) async {
    try {
      final res = await _client.dio.get('/presence/$uid');
      // Response shape: { ok, data: { state, lastChanged } }.
      final data = apiDataMap(res.data);
      if (data == null) return null;
      return PresenceState.fromWire(data['state'] as String?);
    } on Exception catch (e) {
      // 404 = user has never reported a state. Treat as offline and
      // suppress the log line so it doesn't drown the console.
      if (!e.toString().contains('404')) {
        debugPrint('[RemotePresenceRepository.getState] $e');
      }
      return _fallback.getState(uid);
    }
  }

  @override
  Stream<Set<String>> watchOnline(List<String> uids) async* {
    if (uids.isEmpty) {
      yield const <String>{};
      return;
    }

    final controller = StreamController<Set<String>>();
    Timer? timer;

    Future<void> tick() async {
      // Fan out a presence request per uid and collect the ones that
      // report `online`. Failures for any individual uid are
      // swallowed (the user is treated as offline); we still want
      // to update the rest of the list.
      final results = await Future.wait(
        uids.map((uid) async {
          try {
            final state = await getState(uid);
            return MapEntry(uid, state == PresenceState.online);
          } catch (_) {
            return MapEntry(uid, false);
          }
        }),
      );
      final online = <String>{
        for (final entry in results)
          if (entry.value) entry.key,
      };
      if (!controller.isClosed) controller.add(online);
    }

    // Emit immediately, then on every interval tick.
    unawaited(tick());
    timer = Timer.periodic(_onlinePollInterval, (_) => tick());

    controller.onCancel = () {
      timer?.cancel();
      timer = null;
    };

    yield* controller.stream;
  }
}
