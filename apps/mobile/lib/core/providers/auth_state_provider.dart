import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_token_store.dart';

// ─── Domain ──────────────────────────────────────────────────────────────────

/// Represents the authentication state of the current session.
enum AuthStatus {
  /// Initial state — session check not complete yet.
  unknown,

  /// Valid access token exists in secure storage.
  authenticated,

  /// No token or token cleared (logged out).
  unauthenticated,
}

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.userId});

  final AuthStatus status;

  /// The stored user ID, or null when unauthenticated.
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

  /// Called at app start (splash screen). Reads secure storage and sets state.
  Future<void> checkSession() async {
    final hasSession = await _store.hasValidSession;
    if (hasSession) {
      final userId = await _store.readUserId();
      state = AuthState(status: AuthStatus.authenticated, userId: userId);
    } else {
      state = AuthState.unauthenticated;
    }
  }

  /// Called after successful login. Persists tokens and sets authenticated.
  Future<void> signIn({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      _store.saveAccessToken(accessToken),
      _store.saveRefreshToken(refreshToken),
      _store.saveUserId(userId),
    ]);
    state = AuthState(status: AuthStatus.authenticated, userId: userId);
  }

  /// Called on logout. Clears ALL tokens and navigates to unauthenticated.
  Future<void> signOut() async {
    await _store.clearAll();
    state = AuthState.unauthenticated;
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(),
);

/// Convenience: just the status enum.
final authStatusProvider = Provider<AuthStatus>(
  (ref) => ref.watch(authStateProvider).status,
);

/// True when session check has completed AND user is authenticated.
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authStateProvider).isAuthenticated,
);
