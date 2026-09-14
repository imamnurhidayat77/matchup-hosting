import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';

/// Signs the Firebase SDK into the same Firebase user the backend
/// already authenticated via the ID token.
///
/// The app authenticates against Firebase through plain REST
/// ([RemoteAuthRepository]), so the native SDKs (`firebase_database`,
/// `firebase_storage`) have no user — RTDB listeners hit security
/// rules as anonymous and get `permission-denied`, silently pushing
/// chat back to 3-second HTTP polling. This service closes that gap:
/// it fetches a short-lived custom token from
/// `POST /api/users/custom-token` (which requires a valid ID token)
/// and signs the SDK in with it, so realtime listeners run as the
/// real user.
///
/// Every method is a safe no-op when Firebase isn't configured
/// (no `firebase_options.dart` / platform config files) and never
/// throws — callers must not gate UX on it.
class RtdbAuthService {
  RtdbAuthService._();

  static final RtdbAuthService instance = RtdbAuthService._();

  /// Ensures the Firebase SDK has a signed-in user. Skips when one
  /// already exists. Call after sign-in/register and once at app
  /// start when a stored session is restored.
  Future<void> ensureSignedIn() async {
    if (!_isFirebaseReady()) return;
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser != null) return;
      final res = await ApiClient.instance.dio.post('/users/custom-token');
      final token = apiDataMap(res.data)?['customToken'] as String?;
      if (token == null || token.isEmpty) {
        debugPrint('[RtdbAuthService] empty custom token');
        return;
      }
      await auth.signInWithCustomToken(token);
    } catch (e, st) {
      debugPrint('[RtdbAuthService.ensureSignedIn] $e\n$st');
    }
  }

  /// Signs the SDK out. Call on app sign-out so the next account
  /// doesn't inherit the previous user's RTDB session.
  Future<void> signOut() async {
    if (!_isFirebaseReady()) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e, st) {
      debugPrint('[RtdbAuthService.signOut] $e\n$st');
    }
  }

  bool _isFirebaseReady() {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
