import 'dart:async';

/// Forwards every event of [source], but throws [TimeoutException] if the
/// first event takes longer than [timeout] instead of hanging forever.
///
/// RTDB `onValue` listeners are the motivating case: when the socket
/// stalls (blackholed route, wedged connection) the stream emits neither
/// data nor error, so a chat screen would sit on its skeleton with no
/// error and no retry. Callers catch the timeout and fall back to HTTP
/// polling.
///
/// Only the FIRST event is timed: a quiet chat legitimately emits
/// nothing for hours, and timing out idle gaps would flap between
/// realtime and polling. A stalled first event, however, proves the
/// listener never attached.
///
/// Implementation uses a manual [StreamSubscription] (not
/// [StreamIterator]): cancelling an iterator while its `moveNext` is
/// pending hangs forever, which would leak every disposed chat
/// subscription. A raw subscription cancels promptly at any point.
Stream<T> withFirstEventTimeout<T>(
  Stream<T> source, {
  Duration timeout = const Duration(seconds: 10),
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? sub;
  Timer? watchdog;
  var gotFirst = false;

  void onFirstTimeout() {
    if (gotFirst || controller.isClosed) return;
    unawaited(sub?.cancel());
    sub = null;
    controller.addError(
      TimeoutException('No stream event within $timeout (listener stalled)'),
    );
    unawaited(controller.close());
  }

  controller = StreamController<T>(
    onListen: () {
      watchdog = Timer(timeout, onFirstTimeout);
      sub = source.listen(
        (event) {
          gotFirst = true;
          watchdog?.cancel();
          watchdog = null;
          controller.add(event);
        },
        onError: (Object e, StackTrace st) {
          watchdog?.cancel();
          watchdog = null;
          controller.addError(e, st);
        },
        onDone: () {
          watchdog?.cancel();
          watchdog = null;
          controller.close();
        },
        cancelOnError: false,
      );
    },
    onCancel: () async {
      watchdog?.cancel();
      watchdog = null;
      await sub?.cancel();
      sub = null;
    },
  );
  return controller.stream;
}
