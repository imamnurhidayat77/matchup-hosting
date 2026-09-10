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

// ─── Response envelope ────────────────────────────────────────────────────────
//
// Every api-server endpoint wraps its payload in `{ok: true, data: T}` on
// success and `{ok: false, error: {code, message}}` on failure. Dio
// exposes the whole decoded body as `Response.data`, so repositories
// must unwrap `.data` before parsing — parsing the envelope itself is
// the #1 cause of "empty screen with a healthy backend".

/// Returns the `data` payload of an api-server envelope.
///
/// If [body] is already the raw payload (no `data` key — e.g. a hand-
/// built mock in a test), it is returned as-is so callers stay
/// agnostic.
Object? apiData(Object? body) {
  if (body is Map && body['data'] != null) return body['data'];
  return body;
}

/// Unwraps an enveloped object payload into a JSON map, or `null` when
/// the payload is missing / not a map.
Map<String, dynamic>? apiDataMap(Object? body) {
  final data = apiData(body);
  return data is Map<String, dynamic>
      ? data
      : data is Map
          ? Map<String, dynamic>.from(data)
          : null;
}

/// Unwraps an enveloped list payload. Returns an empty list when the
/// payload is missing / not a list.
List<dynamic> apiDataList(Object? body) {
  final data = apiData(body);
  return data is List ? data : const [];
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
    // Error bodies are enveloped as `{ok: false, error: {code,
    // message}}`; fall back to top-level `message`/`code` for
    // non-enveloped payloads (e.g. Firebase REST errors).
    final body = err.response?.data;
    final errBody = body is Map ? body['error'] : null;
    final serverMsg = (errBody is Map ? errBody['message'] : null) as String? ??
        (body is Map ? body['message'] as String? : null);
    final serverCode = (errBody is Map ? errBody['code'] : null) as String? ??
        (body is Map ? body['code'] as String? : null);

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
