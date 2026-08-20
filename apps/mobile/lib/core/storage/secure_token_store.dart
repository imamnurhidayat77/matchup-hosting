import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys for secure token storage.
const _kAccessToken = 'auth_access_token';
const _kRefreshToken = 'auth_refresh_token';
const _kUserId = 'auth_user_id';

/// Stores and retrieves auth tokens using the platform secure enclave
/// (Keychain on iOS, Keystore-backed EncryptedSharedPreferences on Android).
///
/// NEVER store tokens in [SharedPreferences] or Hive without encryption.
class SecureTokenStore {
  SecureTokenStore._()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  static final SecureTokenStore instance = SecureTokenStore._();

  final FlutterSecureStorage _storage;

  // ── Access token ────────────────────────────────────────────────────────

  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _kAccessToken, value: token);

  Future<String?> readAccessToken() =>
      _storage.read(key: _kAccessToken);

  // ── Refresh token ───────────────────────────────────────────────────────

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _kRefreshToken, value: token);

  Future<String?> readRefreshToken() =>
      _storage.read(key: _kRefreshToken);

  // ── User ID ─────────────────────────────────────────────────────────────

  Future<void> saveUserId(String id) =>
      _storage.write(key: _kUserId, value: id);

  Future<String?> readUserId() =>
      _storage.read(key: _kUserId);

  // ── Session helpers ─────────────────────────────────────────────────────

  Future<bool> get hasValidSession async {
    final token = await readAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Call on logout. Deletes ALL stored tokens.
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
    ]);
  }
}
