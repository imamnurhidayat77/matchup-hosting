import 'dart:async';

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
}
