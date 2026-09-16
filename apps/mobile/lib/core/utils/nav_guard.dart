import 'dart:async';

import 'package:flutter/foundation.dart';

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
  }
}
