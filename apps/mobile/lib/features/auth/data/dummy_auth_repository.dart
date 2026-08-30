import 'auth_repository.dart';

/// In-memory [AuthRepository] — always succeeds, no network required.
/// Produces deterministic dummy tokens so the rest of the app
/// (routing, profile loading, SecureTokenStore) behaves identically to
/// the real backend path.
class DummyAuthRepository implements AuthRepository {
  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // Any email/password succeeds — matches the pre-existing UX.
    return const AuthResult(
      accessToken: 'dummy_access_token',
      refreshToken: 'dummy_refresh_token',
      userId: 'demo_user_001',
    );
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return const AuthResult(
      accessToken: 'dummy_access_token',
      refreshToken: 'dummy_refresh_token',
      userId: 'me',
    );
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  @override
  Future<void> verifyOtp({required String email, required String code}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // Dummy: any 6-digit code is valid except all-zeros (simulate wrong code).
    if (code == '000000') {
      throw const AuthException(
        'Incorrect code. Please try again.',
        code: 'INVALID_OTP',
      );
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  @override
  Future<void> signOut() async {}
}
