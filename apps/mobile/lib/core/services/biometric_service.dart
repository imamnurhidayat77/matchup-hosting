import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper around [local_auth] for biometric login (optional feature).
///
/// Class-two feature per `mobile-design.md` §5.4: "Optional biometric login
/// if implemented later". This service is opt-in and degrades gracefully on
/// devices without biometric hardware or enrolled credentials.
class BiometricService {
  BiometricService._();

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
  Future<bool> authenticate({
    String reason = 'Please authenticate to sign in to MatchUp',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('BiometricService.authenticate: ${e.code} ${e.message}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('BiometricService.authenticate: $e');
      return false;
    }
  }
}
