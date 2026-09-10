import 'auth_repository.dart';

/// Stub [AuthRepository] used as a graceful-degradation fallback when
/// the live Firebase REST endpoint is unreachable.
///
/// Every method throws — there's no fake "sign in with anything"
/// behaviour. The production app **always** uses
/// [RemoteAuthRepository]; this class only exists so the provider
/// has a non-null value when the env flag is flipped (and so unit
/// tests can override the binding with a mock).
class LocalAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    throw const AuthException(
      'Sign-in requires a live backend. Check your connection and try again.',
      code: 'NO_BACKEND',
    );
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    throw const AuthException(
      'Registration requires a live backend. Check your connection and try again.',
      code: 'NO_BACKEND',
    );
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    throw const AuthException(
      'Password reset requires a live backend.',
      code: 'NO_BACKEND',
    );
  }

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    throw const AuthException(
      'OTP verification requires a live backend.',
      code: 'NO_BACKEND',
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    throw const AuthException(
      'Password reset requires a live backend.',
      code: 'NO_BACKEND',
    );
  }

  @override
  Future<void> signOut() async {}
}
