import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/session_events.dart';
import '../config/env.dart';
import '../storage/secure_token_store.dart';

/// Base path — matches the api-server route prefix.
const String _apiBase = '/api';

/// Production-ready Dio client with three interceptors:
///   1. [AuthInterceptor]       — inject stored Firebase ID token; refresh on 401.
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
      AuthInterceptor(),
      _ErrorInterceptor(),
      if (kDebugMode) _LoggingInterceptor(),
    ]);

    return dio;
  }
}

// ─── Interceptors ────────────────────────────────────────────────────────────

/// Result of a refresh attempt, so callers can tell "try again
/// later" apart from "session is dead, send the user to login".
enum RefreshOutcome { refreshed, transientFailure, deadSession }

/// HTTP exchange with the Firebase securetoken endpoint.
///
/// Takes the stored refresh token, returns the fresh token pair.
/// Throws [UnrecoverableRefreshException] when the session itself is
/// dead (rejected/revoked refresh token, disabled user) and
/// [TransientRefreshException] for anything worth retrying later
/// (timeout, network, 5xx, unexpected shape).
typedef SecureTokenExchange = Future<SecureTokenPair> Function(
  String refreshToken,
);

/// Fresh tokens from a securetoken exchange.
class SecureTokenPair {
  const SecureTokenPair({required this.idToken, this.refreshToken});
  final String idToken;
  final String? refreshToken;
}

/// The refresh token itself was rejected — re-login is the only way out.
class UnrecoverableRefreshException implements Exception {
  const UnrecoverableRefreshException(this.message);
  final String message;
  @override
  String toString() => 'UnrecoverableRefreshException($message)';
}

/// Network/timeout/server-side blip — safe to retry on a later 401.
class TransientRefreshException implements Exception {
  const TransientRefreshException(this.message);
  final String message;
  @override
  String toString() => 'TransientRefreshException($message)';
}

/// Injects the stored Firebase ID token and keeps it alive.
///
/// The ID token is a short-lived JWT issued by Firebase — expired after
/// 1 hour. Two mechanisms prevent the old "works for an hour, then 401
/// forever" death spiral:
///
///   * Proactive: [onRequest] decodes the token's `exp` claim (no
///     verification — expiry is not a trust decision) and refreshes
///     up to 5 minutes before expiry, so most requests never 401.
///   * Reactive: on 401, one shared refresh runs (concurrent requests
///     join it instead of stampeding securetoken), then the failed
///     request is retried exactly once (guarded by [_retriedHeader]).
///
/// When the refresh token itself is rejected, the session is
/// unrecoverable: storage is cleared and [SessionEvents] fires so the
/// app routes to login instead of sitting in a zombie session.
///
/// Public (rather than private) so tests can drive the full
/// 401 → refresh → retry flow with an in-memory token store and a fake
/// securetoken exchange. Production always uses the default constructor
/// (secure storage + real Google endpoint).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    Future<String?> Function()? readAccessToken,
    Future<void> Function(String)? saveAccessToken,
    Future<String?> Function()? readRefreshToken,
    Future<void> Function(String)? saveRefreshToken,
    Future<void> Function()? clearTokens,
    String Function()? apiKeyProvider,
    SecureTokenExchange? exchange,
    // Separated for tests: production retries through the shared
    // singleton (same interceptors, same base URL); tests route the
    // retry through their own Dio pointed at a local fake backend.
    Future<Response<dynamic>> Function(RequestOptions)? retryFetch,
  })  : _readAccessToken =
            readAccessToken ?? SecureTokenStore.instance.readAccessToken,
        _saveAccessToken =
            saveAccessToken ?? SecureTokenStore.instance.saveAccessToken,
        _readRefreshToken =
            readRefreshToken ?? SecureTokenStore.instance.readRefreshToken,
        _saveRefreshToken =
            saveRefreshToken ?? SecureTokenStore.instance.saveRefreshToken,
        _clearTokens = clearTokens ?? SecureTokenStore.instance.clearAll,
        _apiKeyProvider = apiKeyProvider ?? (() => Env.firebaseWebApiKey),
        _exchange = exchange ?? secureTokenExchange,
        _retryFetch =
            retryFetch ?? ((opts) => ApiClient.instance.dio.fetch(opts));

  final Future<String?> Function() _readAccessToken;
  final Future<void> Function(String) _saveAccessToken;
  final Future<String?> Function() _readRefreshToken;
  final Future<void> Function(String) _saveRefreshToken;
  final Future<void> Function() _clearTokens;
  final String Function() _apiKeyProvider;
  final SecureTokenExchange _exchange;
  final Future<Response<dynamic>> Function(RequestOptions) _retryFetch;

  /// Header marking a request that already went through one
  /// refresh-and-retry cycle — prevents infinite 401 loops when the
  /// server keeps rejecting even a fresh token.
  static const _retriedHeader = 'x-matchup-retried';

  /// Refreshes with a 5-minute expiry skew.
  static const _refreshSkew = Duration(minutes: 5);

  /// Coalesces concurrent refreshes into one network call.
  Future<RefreshOutcome>? _refreshInFlight;

  /// Cooldown after a failed refresh: when Google is unreachable (dead
  /// emulator DNS, airplane mode), every request would otherwise burn
  /// ~30s on doomed refresh attempts before surfacing its 401. Skip
  /// the network call while a recent failure is still fresh so errors
  /// surface fast; the next attempt happens automatically afterwards.
  static const _failureCooldown = Duration(seconds: 60);
  DateTime? _lastRefreshFailureAt;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var token = await _readAccessToken();
    if (token != null && token.isNotEmpty) {
      // Proactive refresh: never send a token that dies mid-flight.
      // Best-effort — a failed proactive refresh still sends the old
      // token and lets the reactive path handle a 401.
      if (isIdTokenExpiringSoon(token, skew: _refreshSkew)) {
        final outcome = await _sharedRefresh();
        if (outcome == RefreshOutcome.refreshed) {
          token = await _readAccessToken();
        }
      }
    }
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
    // Suspension signal: never retried, never refreshed — broadcast so
    // the UI gates to the suspended interstitial. Tokens are kept (the
    // user needs them to file and track an appeal).
    final body = err.response?.data;
    final errBody = body is Map ? body['error'] : null;
    final code = (errBody is Map ? errBody['code'] : null) as String?;
    if (err.response?.statusCode == 403 && code == 'ACCOUNT_SUSPENDED') {
      SessionEvents.instance.notifySuspended();
      return handler.next(err);
    }
    if (err.response?.statusCode == 401 &&
        err.requestOptions.headers[_retriedHeader] == null) {
      final outcome = await _sharedRefresh();
      if (outcome == RefreshOutcome.refreshed) {
        final token = await _readAccessToken();
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $token';
        opts.headers[_retriedHeader] = '1';
        try {
          final response = await _retryFetch(opts);
          debugPrint(
            '[ApiClient] retry after refresh -> ${response.statusCode} '
            '${opts.path}',
          );
          return handler.resolve(response);
        } on DioException catch (e) {
          // Retry failed too — fall through to the original error.
          // Logged (with status, never the token) because a 401 here
          // after a successful refresh means the backend rejects even
          // fresh tokens — check the backend `[auth] verifyIdToken
          // rejected:` line for expired vs revoked vs invalid.
          debugPrint(
            '[ApiClient] retry after refresh failed: '
            'HTTP ${e.response?.statusCode} ${opts.path}',
          );
        } catch (_) {
          // Retry failed too — fall through to the original error.
        }
      } else if (outcome == RefreshOutcome.deadSession) {
        await _clearTokens();
        SessionEvents.instance.notifySessionExpired();
      }
    }
    handler.next(err);
  }

  /// Returns the in-flight refresh, or starts one. Guarantees at most
  /// one securetoken call at a time no matter how many requests 401
  /// together.
  Future<RefreshOutcome> _sharedRefresh() {
    return _refreshInFlight ??= _tryRefreshFirebaseToken().whenComplete(
      () => _refreshInFlight = null,
    );
  }

  /// Exchanges the stored Firebase refresh token for a fresh ID token.
  /// Transient failures are retried once inside [_exchange]; rejections
  /// that mean the session itself is dead surface as [deadSession].
  Future<RefreshOutcome> _tryRefreshFirebaseToken() async {
    final lastFailure = _lastRefreshFailureAt;
    if (lastFailure != null &&
        DateTime.now().difference(lastFailure) < _failureCooldown) {
      debugPrint('[ApiClient] refresh skipped (cooldown after recent failure)');
      return RefreshOutcome.transientFailure;
    }

    final refreshToken = await _readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      debugPrint('[ApiClient] no stored refresh token — session dead');
      return RefreshOutcome.deadSession;
    }

    final apiKey = _apiKeyProvider();
    if (apiKey.isEmpty) {
      debugPrint('[ApiClient] token refresh skipped: no web API key');
      _lastRefreshFailureAt = DateTime.now();
      return RefreshOutcome.transientFailure;
    }

    try {
      // exp timestamps (not token contents) help diagnose skew: if the
      // backend keeps 401ing a token whose exp is in the future, the
      // device clock or revocation — not expiry — is the problem. See
      // the backend `[auth] verifyIdToken rejected:` line for the cause.
      final now = DateTime.now().millisecondsSinceEpoch;
      final oldExp = await _readAccessToken().then(idTokenExpiryMs);
      final pair = await _exchange(refreshToken);
      await _saveAccessToken(pair.idToken);
      if (pair.refreshToken != null && pair.refreshToken!.isNotEmpty) {
        await _saveRefreshToken(pair.refreshToken!);
      }
      debugPrint(
        '[ApiClient] token refreshed (old exp=$oldExp now=$now '
        'new exp=${idTokenExpiryMs(pair.idToken)})',
      );
      return RefreshOutcome.refreshed;
    } on UnrecoverableRefreshException catch (e) {
      debugPrint('[ApiClient] refresh token rejected — session dead ($e)');
      return RefreshOutcome.deadSession;
    } on TransientRefreshException catch (e) {
      debugPrint('[ApiClient] token refresh failed: $e');
      _lastRefreshFailureAt = DateTime.now();
      return RefreshOutcome.transientFailure;
    } catch (e) {
      debugPrint('[ApiClient] token refresh failed: $e');
      _lastRefreshFailureAt = DateTime.now();
      return RefreshOutcome.transientFailure;
    }
  }
}

/// Default [SecureTokenExchange]: the real Firebase securetoken REST
/// endpoint. Transient failures (timeout, network, 5xx) are retried
/// once; rejections that mean the session itself is dead throw
/// [UnrecoverableRefreshException].
///
/// Budget: each attempt fails fast (~10s worst case) so a blackholed
/// route to Google stalls the app for seconds, not half a minute —
/// the failure cooldown then lets 401s surface immediately until the
/// network recovers.
Future<SecureTokenPair> secureTokenExchange(String refreshToken) async {
  final apiKey = Env.firebaseWebApiKey;
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      final plain = Dio();
      final res = await plain
          .post(
            'https://securetoken.googleapis.com/v1/token?key=$apiKey',
            data: {
              'grant_type': 'refresh_token',
              'refresh_token': refreshToken,
            },
            options: Options(
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
              },
              sendTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
            ),
          )
          .timeout(const Duration(seconds: 10));

      final data = res.data;
      final newIdToken =
          data is Map ? data['id_token'] as String? : null;
      final newRefreshToken =
          data is Map ? data['refresh_token'] as String? : null;

      if (newIdToken == null || newIdToken.isEmpty) {
        throw const TransientRefreshException('empty id_token in response');
      }
      return SecureTokenPair(
        idToken: newIdToken,
        refreshToken: newRefreshToken,
      );
    } on TimeoutException {
      debugPrint('[ApiClient] token refresh timed out (attempt $attempt)');
      continue;
    } on DioException catch (e) {
      if (isUnrecoverableRefreshError(e)) {
        throw UnrecoverableRefreshException(
          _refreshErrorMessage(e) ?? e.toString(),
        );
      }
      final status = e.response?.statusCode;
      debugPrint('[ApiClient] token refresh HTTP $status: ${_refreshErrorMessage(e)}');
      continue;
    } catch (e) {
      debugPrint('[ApiClient] token refresh failed: $e');
      continue;
    }
  }
  throw const TransientRefreshException('exhausted retries');
}

/// Best-effort Google error message for refresh-failure logs.
String? _refreshErrorMessage(DioException e) {
  final body = e.response?.data;
  if (body is Map && body['error'] is Map) {
    final message = (body['error'] as Map)['message'];
    if (message != null) return message.toString();
  }
  return e.message;
}

/// True when the securetoken error means the session itself is dead
/// (bad/expired/revoked refresh token, disabled user) as opposed to a
/// transient failure worth retrying.
@visibleForTesting
bool isUnrecoverableRefreshError(DioException e) {
  final status = e.response?.statusCode;
  if (status == null) return false;
  if (status >= 500) return false;
  final body = e.response?.data;
  Object? errField;
  if (body is Map && body['error'] is Map) {
    errField = (body['error'] as Map)['message'];
  }
  final message =
      errField?.toString() ?? e.message ?? '';
  const deadMarkers = [
    'INVALID_REFRESH_TOKEN',
    'TOKEN_EXPIRED',
    'USER_DISABLED',
    'USER_NOT_FOUND',
    'INVALID_GRANT',
  ];
  return deadMarkers.any(message.contains);
}

/// True when [idToken]'s `exp` claim is within [skew] of now (or the
/// token is unparseable, in which case refreshing early is the safe
/// move — the reactive 401 path remains as backstop).
@visibleForTesting
bool isIdTokenExpiringSoon(String idToken, {required Duration skew}) {
  final expMs = idTokenExpiryMs(idToken);
  if (expMs == null) return true;
  return DateTime.now().millisecondsSinceEpoch + skew.inMilliseconds >= expMs;
}

/// Epoch-millis `exp` of a JWT without verifying its signature.
/// Expiry is a freshness hint, not a trust decision — verification
/// stays server-side. Returns null when missing or unparseable.
@visibleForTesting
int? idTokenExpiryMs(String? idToken) {
  if (idToken == null) return null;
  try {
    final parts = idToken.split('.');
    if (parts.length != 3) return null;
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    payload += '=' * ((4 - payload.length % 4) % 4);
    final json =
        jsonDecode(utf8.decode(base64.decode(payload))) as Map<String, dynamic>;
    final exp = json['exp'];
    if (exp is num) return exp.toInt() * 1000;
    return null;
  } catch (_) {
    return null;
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

  /// True when the backend reports a suspended account (403 +
  /// `ACCOUNT_SUSPENDED`). Distinct from other 403s (e.g. host-only
  /// actions) — drives the global suspended gate, not an error toast.
  bool get isAccountSuspended =>
      statusCode == 403 && code == 'ACCOUNT_SUSPENDED';

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
        userMessage: serverMsg ?? _defaultMessage(status, code: serverCode),
        code: serverCode,
      ),
    };
  }

  static String _defaultMessage(int? status, {String? code}) => switch (status) {
    400 => 'Invalid request. Please check your input.',
    401 => 'Session expired. Please sign in again.',
    403 when code == 'ACCOUNT_SUSPENDED' =>
      'Your account has been suspended.',
    403 => 'You don\'t have permission to do this.',
    404 => 'The requested resource was not found.',
    429 => 'Too many requests. Please wait a moment.',
    500 || 502 || 503 => 'Server error. Please try again later.',
    _ => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => 'ApiException($statusCode: $userMessage)';
}
