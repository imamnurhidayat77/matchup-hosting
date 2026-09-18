import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Prevents the same navigation action from firing twice in quick
/// succession (double-tap, or a slow first frame making a second tap land
/// before the route push registers).
///
/// A duplicate `context.push(path)` before the first push has been
/// processed creates two [Page]s with the same derived key, which throws
/// `'!keyReservation.contains(key)': is not true` in `navigator.dart` —
/// this was the actual crash on Report from both Activity Detail and
/// Player Profile. Wrap the tap handler instead of converting the
/// enclosing widget to a `StatefulWidget` just to track a bool flag:
///
/// ```dart
/// PressableScale(
///   onTap: () => NavGuard.once(() => context.push('/some/$id')),
///   child: ...,
/// )
/// ```
///
/// Report Activity was migrated off this helper: it's now a modal sheet
/// (`ReportActivitySheet.show`), so double-tap can't collide because modal
/// sheets live in an [Overlay], not a [Page] stack.
class NavGuard {
  NavGuard._();

  static bool _busy = false;

  /// Per-key last-run timestamps so independent actions (e.g. GTK next,
  /// resend, apply) don't block each other — only the same key debounces.
  static final Map<String, DateTime> _lastRun = {};

  /// Runs [action] only if no other guarded action is currently in
  /// flight. Automatically releases after [cooldown] so a genuinely new
  /// tap later is never permanently blocked by a stuck flag.
  static void once(void Function() action, {Duration? cooldown}) {
    if (_busy) return;
    _busy = true;
    action();
    Timer(cooldown ?? const Duration(milliseconds: 600), () {
      _busy = false;
    });
  }

  /// Per-key variant of [once]: debounces rapid repeats of the same
  /// [key] within [cooldown] (default 600ms) while letting different
  /// keys run independently. Use for push chains where the global
  /// [_busy] would over-block (GTK 1→2→3, reset-link-sent, filter apply).
  ///
  /// ```dart
  /// PressableScale(
  ///   onTap: () => NavGuard.onceFor(
  ///     'gtk-1-next',
  ///     () => context.push('/get-to-know-2'),
  ///   ),
  ///   child: ...,
  /// )
  /// ```
  ///
  /// NOTE: [onceFor] only covers taps within [cooldown]. A second tap
  /// after the window (slow transition, impatient user) still pushes a
  /// duplicate page and red-screens. For `push` navigation prefer
  /// [pushOnce] below, which is correct regardless of timing.
  static void onceFor(
    String key,
    void Function() action, {
    Duration? cooldown,
  }) {
    final now = DateTime.now();
    final last = _lastRun[key];
    final window = cooldown ?? const Duration(milliseconds: 600);
    if (last != null && now.difference(last) < window) return;
    _lastRun[key] = now;
    action();
  }

  @visibleForTesting
  static void resetForTest() {
    _busy = false;
    _lastRun.clear();
    _inFlightSince.clear();
  }

  /// Safety-net window for [push]/[pushT]/[pushOnce]: a key older than
  /// this is treated as stale and released on the next check, even if
  /// `context.push()`'s Future never resolved.
  ///
  /// That Future only resolves on a genuine pop — go_router's
  /// `ImperativeRouteMatch` completer is only completed from the pop
  /// path (`_completeRouteMatch` in its delegate). A `context.go(...)`
  /// elsewhere (e.g. tapping a bottom-nav tab while this push is still
  /// on the stack) replaces the whole route match list from scratch and
  /// discards that completer without ever resolving it, permanently
  /// stranding the key — every future tap to the same location silently
  /// no-ops until the app is restarted (observed: the Notifications
  /// bell going dead after switching tabs instead of using the
  /// in-screen back arrow). Far longer than any real transition, so it
  /// never reintroduces the double-push race this guard exists to
  /// prevent.
  ///
  /// Checked lazily on the next [_isStuck] call rather than via a
  /// scheduled `Timer` — a live Timer left running past a normal pop
  /// (cancelled) is fine, but one left running because the test/screen
  /// never popped at all trips flutter_test's "Timer still pending
  /// after dispose" assertion; plain timestamps avoid that entirely.
  static const Duration _pushSafetyNet = Duration(seconds: 5);

  /// In-flight pushes by key, timestamped when reserved. A key stays
  /// reserved from `push` until the pushed route is popped
  /// (`context.push` completes on pop) or [_pushSafetyNet] elapses —
  /// whichever comes first — so a repeat tap can never create a
  /// duplicate page, and a key can never be stuck forever either.
  /// Prefer this over [onceFor] for every `push` whose page key derives
  /// from an id.
  static final Map<String, DateTime> _inFlightSince = {};

  static bool _isStuck(String key) {
    final since = _inFlightSince[key];
    if (since == null) return false;
    if (clock.now().difference(since) > _pushSafetyNet) {
      _inFlightSince.remove(key);
      return false;
    }
    return true;
  }

  /// Pushes [location] once per location: repeat taps for the same
  /// destination while its page is still on the stack are ignored, so
  /// duplicate page keys (`'!keyReservation.contains(key)'` red screen)
  /// are impossible app-wide no matter how slow the transition is. The
  /// key releases on a normal pop, or after [_pushSafetyNet] if the
  /// route instead leaves the stack via `context.go(...)` — either way
  /// legitimate re-entry always works. Fire-and-forget safe.
  static Future<void> push(
    BuildContext context,
    String location, {
    Object? extra,
  }) async {
    if (_isStuck(location)) return;
    _inFlightSince[location] = clock.now();
    try {
      await context.push(location, extra: extra);
    } finally {
      _inFlightSince.remove(location);
    }
  }

  /// Typed variant of [push] for callers that await a pop result
  /// (e.g. edit screens popping `true` on save). A swallowed duplicate
  /// resolves `null`, which callers already treat as "no change".
  static Future<T?> pushT<T>(
    BuildContext context,
    String location, {
    Object? extra,
  }) async {
    if (_isStuck(location)) return null;
    _inFlightSince[location] = clock.now();
    try {
      return await context.push<T>(location, extra: extra);
    } finally {
      _inFlightSince.remove(location);
    }
  }

  /// Pushes [location] once: repeat taps while the route is still on
  /// the stack are ignored. Fire-and-forget safe (`onTap: () =>
  /// NavGuard.pushOnce(context, 'chat-$id', '/chat/$id')`) — lifecycle
  /// is tracked internally and always released in `finally`, even if
  /// the push itself throws.
  static Future<void> pushOnce(
    BuildContext context,
    String key,
    String location, {
    Object? extra,
  }) async {
    if (_isStuck(key)) return;
    _inFlightSince[key] = clock.now();
    try {
      await context.push(location, extra: extra);
    } finally {
      _inFlightSince.remove(key);
    }
  }
}
