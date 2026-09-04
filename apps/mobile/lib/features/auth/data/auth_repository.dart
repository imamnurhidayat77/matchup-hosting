/// Result of a successful sign-in or register operation.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;

  /// Server-side user ID — stored in [SecureTokenStore] and used as the
  /// `me` context for profile / activity queries.
  final String userId;
}

/// Abstract contract for every authentication operation the app performs.
///
/// Implementations: [LocalAuthRepository] (local, always succeeds),
/// [RemoteAuthRepository] (live API).
abstract class AuthRepository {
  /// Signs in with email + password. Returns [AuthResult] on success.
  /// Throws [AuthException] on invalid credentials or network error.
  Future<AuthResult> signIn({
    required String email,
    required String password,
  });

  /// Creates a new account. Returns [AuthResult] on success (auto-login).
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  });

  /// Sends a one-time password to [email] for password reset.
  Future<void> forgotPassword({required String email});

  /// Verifies the 6-digit [code] sent to [email].
  /// Throws [AuthException] on wrong code.
  Future<void> verifyOtp({required String email, required String code});

  /// Resets the password after OTP verification succeeds.
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  });

  /// Invalidates the current session on the server.
  Future<void> signOut();
}

/// Strongly-typed error for authentication failures.
/// Screens catch this and show [userMessage] directly.
class AuthException implements Exception {
  const AuthException(this.userMessage, {this.code});

  final String userMessage;

  /// Optional server-side error code (e.g. `"INVALID_CREDENTIALS"`).
  final String? code;

  @override
  String toString() => 'AuthException($code): $userMessage';
}
