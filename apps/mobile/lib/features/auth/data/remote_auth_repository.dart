import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'auth_repository.dart';
import 'dummy_auth_repository.dart';

/// HTTP-backed [AuthRepository].
///
/// All calls hit `/api/v1/auth/*`. On network failure the error is
/// re-thrown as [AuthException] so screens show a proper message rather
/// than silently succeeding with dummy data — auth failures are not
/// gracefully recoverable the way a missing activity list might be.
///
/// [DummyAuthRepository] is kept as a fallback only for the [signOut]
/// path — a failing sign-out should still clear local state.
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;
  final _dummy = DummyAuthRepository();

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.dio.post(
        '/api/v1/auth/sign-in',
        data: {'email': email, 'password': password},
      );
      return _parseResult(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toAuthException(e);
    } catch (e) {
      debugPrint('[RemoteAuthRepository.signIn] unexpected: $e');
      throw const AuthException('Sign in failed. Please try again.');
    }
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.dio.post(
        '/api/v1/auth/register',
        data: {'display_name': name, 'email': email, 'password': password},
      );
      return _parseResult(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _toAuthException(e);
    } catch (e) {
      debugPrint('[RemoteAuthRepository.register] unexpected: $e');
      throw const AuthException('Registration failed. Please try again.');
    }
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    try {
      await _client.dio.post(
        '/api/v1/auth/forgot-password',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw _toAuthException(e);
    } catch (e) {
      debugPrint('[RemoteAuthRepository.forgotPassword] unexpected: $e');
      throw const AuthException('Could not send reset email. Please try again.');
    }
  }

  @override
  Future<void> verifyOtp({
    required String email,
    required String code,
  }) async {
    try {
      await _client.dio.post(
        '/api/v1/auth/verify-otp',
        data: {'email': email, 'code': code},
      );
    } on DioException catch (e) {
      throw _toAuthException(e);
    } catch (e) {
      debugPrint('[RemoteAuthRepository.verifyOtp] unexpected: $e');
      throw const AuthException('Verification failed. Please try again.');
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      await _client.dio.post(
        '/api/v1/auth/reset-password',
        data: {'email': email, 'new_password': newPassword},
      );
    } on DioException catch (e) {
      throw _toAuthException(e);
    } catch (e) {
      debugPrint('[RemoteAuthRepository.resetPassword] unexpected: $e');
      throw const AuthException('Password reset failed. Please try again.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.dio.post('/api/v1/auth/sign-out');
    } catch (_) {
      // Sign-out failure is non-fatal — local tokens are always cleared by
      // AuthStateNotifier.signOut() regardless of this call's outcome.
      await _dummy.signOut();
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  AuthResult _parseResult(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;
    final userId = json['user_id']?.toString();

    if (accessToken == null || refreshToken == null || userId == null) {
      throw const AuthException(
        'Unexpected server response. Please try again.',
        code: 'PARSE_ERROR',
      );
    }
    return AuthResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: userId,
    );
  }

  AuthException _toAuthException(DioException e) {
    final err = e.error;
    if (err is ApiException) {
      return AuthException(err.userMessage, code: err.code);
    }
    // Fallback for non-intercepted errors (e.g. connection refused in test).
    return AuthException(
      e.message ?? 'Network error. Please check your connection.',
    );
  }
}
