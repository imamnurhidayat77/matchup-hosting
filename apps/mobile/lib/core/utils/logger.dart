/// Minimal debug logger. Swap for `package:logger` in MVP if richer
/// formatting is needed.
void logInfo(String message) {
  // ignore: avoid_print
  print('[info] $message');
}

void logError(String message, [Object? error]) {
  // ignore: avoid_print
  print('[error] $message${error != null ? ': $error' : ''}');
}