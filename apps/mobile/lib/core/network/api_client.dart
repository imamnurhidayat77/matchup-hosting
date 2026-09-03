import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/secure_token_store.dart';

/// Base path — matches the api-server route prefix.
const String _apiBase = '/api';

/// Production-ready Dio client with three interceptors:
///   1. [_AuthInterceptor]    — inject stored Firebase ID token; refresh on 401.
///   2. [_ErrorInterceptor]   — normalise Dio errors into [ApiException].
///   3. [_LoggingInterceptor] — debug-only, redacts sensitive headers.
class ApiClient {
  ApiClient._() : _dio = _buildDio();

  static final ApiClient instance = ApiClient._();

  final Dio _dio;

  Dio get dio => _dio;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '${Env.apiBaseUrl}$_apiBase',
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        followRedirects: false,
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(),
      _ErrorInterceptor(),
      if (kDebugMode) _LoggingInterceptor(),
    ]);

    return dio;
  }
}

// ─── Interceptors ────────────────────────────────────────────────────────────

/// Injects the stored Firebase ID token and handles a single 401 refresh cycle.
/// The ID token is a short-lived JWT issued by Firebase — expired after 1 hour.
/// On 401, we call the Firebase securetoken REST endpoint to get a fresh one.
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureTokenStore.instance.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      try {
        final refreshed = await _tryRefreshFirebaseToken();
        if (refreshed) {
          final token = await SecureTokenStore.instance.readAccessToken();
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $token';
          final response = await ApiClient.instance.dio.fetch(opts);
          return handler.resolve(response);
        }
      } catch (_) {
        await SecureTokenStore.instance.clearAll();
      }
    }
    handler.next(err);
  }

  /// Exchanges the stored Firebase refresh token for a fresh ID token
  /// using the Firebase securetoken REST endpoint.
  Future<bool> _tryRefreshFirebaseToken() async {
    final refreshToken = await SecureTokenStore.instance.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final apiKey = Env.firebaseWebApiKey;
    if (apiKey.isEmpty) return false;

    try {
      final plain = Dio();
      final res = await plain.post(
        'https://securetoken.googleapis.com/v1/token?key=$apiKey',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      final newIdToken = res.data['id_token'] as String?;
      final newRefreshToken = res.data['refresh_token'] as String?;

      if (newIdToken == null) return false;

      await SecureTokenStore.instance.saveAccessToken(newIdToken);
      if (newRefreshToken != null) {
        await SecureTokenStore.instance.saveRefreshToken(newRefreshToken);
      }
      return true;
    } catch (e) {
      debugPrint('[ApiClient] token refresh failed: $e');
      return false;
    }
  }
}

/// Transforms Dio errors into typed [ApiException] objects.
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: ApiException.fromDio(err),
        message: ApiException.fromDio(err).userMessage,
      ),
    );
  }
}

/// Debug-only structured logger. Redacts Authorization header value.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final headers = Map<String, dynamic>.from(options.headers);
    if (headers.containsKey('Authorization')) {
      headers['Authorization'] = 'Bearer [REDACTED]';
    }
    debugPrint('[API] --> ${options.method} ${options.path}  headers:$headers');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[API] <-- ${response.statusCode} ${response.requestOptions.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[API] ERR ${err.response?.statusCode} ${err.requestOptions.path}: '
      '${err.message}',
    );
    handler.next(err);
  }
}

// ─── Domain error types ───────────────────────────────────────────────────────

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.userMessage,
    this.code,
  });

  final int? statusCode;
  final String userMessage;
  final String? code;

  factory ApiException.fromDio(DioException err) {
    final status = err.response?.statusCode;
    final serverMsg = err.response?.data is Map
        ? (err.response!.data as Map)['message'] as String?
        : null;
    final serverCode = err.response?.data is Map
        ? (err.response!.data as Map)['code'] as String?
        : null;

    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiException(
        statusCode: null,
        userMessage: 'Connection timed out. Check your internet connection.',
      ),
      DioExceptionType.connectionError => const ApiException(
        statusCode: null,
        userMessage: 'Cannot reach the server. Check your internet connection.',
      ),
      _ => ApiException(
        statusCode: status,
        userMessage: serverMsg ?? _defaultMessage(status),
        code: serverCode,
      ),
    };
  }

  static String _defaultMessage(int? status) => switch (status) {
    400 => 'Invalid request. Please check your input.',
    401 => 'Session expired. Please sign in again.',
    403 => 'You don\'t have permission to do this.',
    404 => 'The requested resource was not found.',
    429 => 'Too many requests. Please wait a moment.',
    500 || 502 || 503 => 'Server error. Please try again later.',
    _ => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => 'ApiException($statusCode: $userMessage)';
}
