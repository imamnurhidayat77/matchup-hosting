import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Outcome of a biometric prompt, distinguishing user-cancel from real
/// failure so callers can silently return on cancel and only snackbar
/// on genuine errors.
enum BiometricResult { success, cancelled, failed }

/// Thrown when the user cancels the biometric prompt (system cancel,
/// user fallback, or dismissed dialog). Callers should silently return.
class BiometricCancelledException implements Exception {
  const BiometricCancelledException([this.message = 'User cancelled']);
  final String message;
}
class BiometricService {
  BiometricService._();

  /// Thin wrapper around [local_auth] for biometric login (optional feature).
  ///
  /// Class-two feature per `mobile-design.md` §5.4: "Optional biometric login
  /// if implemented later". This service is opt-in and degrades gracefully on
  /// devices without biometric hardware or enrolled credentials.

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether the device has biometric hardware and at least one enrolled
  /// credential. Safe to call on any platform; returns `false` on failure.
  Future<bool> get isAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('BiometricService.isAvailable: ${e.code} ${e.message}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('BiometricService.isAvailable: $e');
      return false;
    }
  }

  /// Authenticate the user with biometrics. Returns `true` on success.
  /// Does not store or verify credentials against the backend — it only
  /// confirms the device owner is present. Pair with a stored session token
  /// to resume a previous login without re-entering the password.
  ///
  /// Returns `false` for both user-cancel and genuine failure (local_auth
  /// reports cancel as `false` on most platforms). Use [authenticateDetailed]
  /// when the caller needs to distinguish the two.
  Future<bool> authenticate({
    String reason = 'Please authenticate to sign in to MatchUp',
  }) async {
    final result = await authenticateDetailed(reason: reason);
    return result == BiometricResult.success;
  }

  /// Detailed variant that distinguishes user-cancel ([BiometricResult.cancelled])
  /// from genuine failure ([BiometricResult.failed]). Platform cancel
  /// signals (`UserCancel`, `Canceled`, `auth_error` with cancel text, or a
  /// plain `false` return) map to cancelled; everything else maps to failed.
  Future<BiometricResult> authenticateDetailed({
    String reason = 'Please authenticate to sign in to MatchUp',
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
      return ok ? BiometricResult.success : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('BiometricService.authenticate: ${e.code} ${e.message}');
      }
      return _isCancelCode(e) ? BiometricResult.cancelled : BiometricResult.failed;
    } catch (e) {
      if (kDebugMode) debugPrint('BiometricService.authenticate: $e');
      return BiometricResult.failed;
    }
  }

  static bool _isCancelCode(PlatformException e) {
    final code = e.code.toLowerCase();
    final msg = (e.message ?? '').toLowerCase();
    const cancelMarkers = [
      'usercancel',
      'user_cancel',
      'canceled',
      'cancelled',
      'systemcancel',
      'appcancel',
      'fallback',
      'dismiss',
    ];
    if (cancelMarkers.any(code.contains)) return true;
    if (code.contains('auth_error') &&
        (msg.contains('cancel') || msg.contains('dismiss'))) {
      return true;
    }
    return false;
  }
}
