import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_events.dart';
import '../network/api_client.dart';
import '../services/rtdb_auth_service.dart';
import '../storage/secure_token_store.dart';

// ─── Domain ──────────────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated, suspended }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.userId});

  final AuthStatus status;

  /// The stored Firebase UID, or null when unauthenticated.
  final String? userId;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnknown => status == AuthStatus.unknown;
  bool get isSuspended => status == AuthStatus.suspended;

  AuthState copyWith({AuthStatus? status, String? userId}) =>
      AuthState(status: status ?? this.status, userId: userId ?? this.userId);

  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
  static const unknown = AuthState(status: AuthStatus.unknown);
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(AuthState.unknown) {
    // Fired by the API layer when the refresh token itself is dead.
    // Re-login is the only recovery — flip to unauthenticated so the
    // router sends the user to login instead of stranding them in a
    // zombie session that 401s forever.
    _expirySub = SessionEvents.instance.onSessionExpired.listen((_) async {
      await _store.clearAll();
      state = AuthState.unauthenticated;
    });
    // Fired by the API layer on 403 ACCOUNT_SUSPENDED. Tokens are KEPT —
    // the user needs them to file and track an appeal — the router gates
    // to the suspended interstitial instead.
    _suspendedSub = SessionEvents.instance.onSuspended.listen((_) {
      if (state.status == AuthStatus.authenticated) {
        state = state.copyWith(status: AuthStatus.suspended);
      }
    });
  }

  final _store = SecureTokenStore.instance;
  late final StreamSubscription<void> _expirySub;
  late final StreamSubscription<void> _suspendedSub;

  @override
  void dispose() {
    _expirySub.cancel();
    _suspendedSub.cancel();
    super.dispose();
  }

  /// Called at app start (splash screen). Reads secure storage to determine
  /// if a valid session exists (stored Firebase ID token + userId).
  Future<void> checkSession() async {
    final hasSession = await _store.hasValidSession;
    if (hasSession) {
      final userId = await _store.readUserId();
      state = AuthState(status: AuthStatus.authenticated, userId: userId);
      // Restore the SDK session too so realtime listeners (chat, typing,
      // presence) run as the real user instead of anonymous.
      unawaited(RtdbAuthService.instance.ensureSignedIn());
    } else {
      state = AuthState.unauthenticated;
    }
  }

  /// Called after successful Firebase REST sign-in/register.
  /// Persists the Firebase ID token (accessToken), refresh token, and userId.
  Future<void> signIn({
    required String accessToken,   // Firebase ID token
    required String refreshToken,  // Firebase refresh token
    required String userId,        // Firebase UID (localId)
  }) async {
    await Future.wait([
      _store.saveAccessToken(accessToken),
      _store.saveRefreshToken(refreshToken),
      _store.saveUserId(userId),
    ]);
    state = AuthState(status: AuthStatus.authenticated, userId: userId);
    // Sign the Firebase SDK in as the same user so RTDB listeners are
    // authenticated. Fire-and-forget: sign-in UX must not wait on it.
    unawaited(RtdbAuthService.instance.ensureSignedIn());
  }

  /// Clears all stored tokens and sets state to unauthenticated.
  Future<void> signOut() async {
    await _store.clearAll();
    // Drop the SDK session too so the next account doesn't inherit it.
    unawaited(RtdbAuthService.instance.signOut());
    state = AuthState.unauthenticated;
  }

  /// Re-checks a suspension (the interstitial's "Check again" action).
  /// A 200 means the account was reactivated → back to authenticated.
  /// 403-suspended, network errors, or anything else → stay suspended
  /// (never log out on a transient failure).
  Future<bool> refreshSuspension() async {
    try {
      await ApiClient.instance.dio.get('/users/me');
      state = state.copyWith(status: AuthStatus.authenticated);
      return true;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final errBody = e.response?.data;
      final errMap = errBody is Map ? errBody['error'] : null;
      final errCode = errMap is Map ? errMap['code'] : null;
      if (code == 403 && errCode == 'ACCOUNT_SUSPENDED') {
        state = state.copyWith(status: AuthStatus.suspended);
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(),
);

final authStatusProvider = Provider<AuthStatus>(
  (ref) => ref.watch(authStateProvider).status,
);

final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).isAuthenticated,
);
