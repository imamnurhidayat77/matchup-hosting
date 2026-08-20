import 'package:flutter/foundation.dart';

/// Structured, release-safe logger for MatchUp.
///
/// Rules (OWASP M6 — Inadequate Privacy Controls):
/// - Output is suppressed entirely in release builds (`kDebugMode == false`).
/// - Never pass PII, passwords, or auth tokens as [message] or [error].
/// - Use [logInfo] for informational events, [logError] for caught errors.
///
/// To log in production (e.g. crash reporting), integrate a privacy-aware
/// SDK (Sentry, Firebase Crashlytics) and call it here instead of printing.

void logInfo(String message) {
  if (kDebugMode) {
    debugPrint('[INFO] $message');
  }
}

void logWarning(String message) {
  if (kDebugMode) {
    debugPrint('[WARN] $message');
  }
}

void logError(String message, [Object? error, StackTrace? stackTrace]) {
  if (kDebugMode) {
    debugPrint('[ERROR] $message${error != null ? ': $error' : ''}');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }
  // TODO: forward to Sentry / Crashlytics in non-debug builds once integrated.
}
