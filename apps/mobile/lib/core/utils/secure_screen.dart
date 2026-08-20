import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mixin that prevents screenshots and screen recording on sensitive screens
/// (OWASP M8 — Security Misconfiguration).
///
/// Usage:
/// ```dart
/// class _LoginScreenState extends State<LoginScreen>
///     with SecureScreenMixin { ... }
/// ```
///
/// Platform behaviour:
/// - Android: sets FLAG_SECURE via MethodChannel → blocks screenshot + screen
///   recording in the system task switcher.
/// - iOS: there is no public API to block screenshots. The OS blurs the app
///   in the app switcher automatically when the app enters the background.
///
/// Call [_setSecure(false)] in dispose if you reuse the mixin on non-leaf
/// screens. The mixin handles this automatically via [initState] / [dispose].
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  static const _channel = MethodChannel('matchup/secure_screen');

  @override
  void initState() {
    super.initState();
    _setSecure(true);
  }

  @override
  void dispose() {
    _setSecure(false);
    super.dispose();
  }

  static Future<void> _setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>(
        'setSecure',
        {'secure': secure},
      );
    } on MissingPluginException {
      // Platform channel not registered (e.g. in unit tests) — ignore.
    } catch (_) {
      // Non-critical: log but don't crash.
    }
  }
}
