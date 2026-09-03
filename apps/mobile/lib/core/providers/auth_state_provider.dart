import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_token_store.dart';

// ─── Domain ──────────────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.userId});

  final AuthStatus status;

  /// The stored Firebase UID, or null when unauthenticated.
  final String? userId;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnknown => status == AuthStatus.unknown;

  AuthState copyWith({AuthStatus? status, String? userId}) =>
      AuthState(status: status ?? this.status, userId: userId ?? this.userId);

  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
  static const unknown = AuthState(status: AuthStatus.unknown);
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(AuthState.unknown);

  final _store = SecureTokenStore.instance;

  /// Called at app start (splash screen). Reads secure storage to determine
  /// if a valid session exists (stored Firebase ID token + userId).
  Future<void> checkSession() async {
    final hasSession = await _store.hasValidSession;
    if (hasSession) {
      final userId = await _store.readUserId();
      state = AuthState(status: AuthStatus.authenticated, userId: userId);
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
  }

  /// Clears all stored tokens and sets state to unauthenticated.
  Future<void> signOut() async {
    await _store.clearAll();
    state = AuthState.unauthenticated;
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
