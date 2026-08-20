import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around `shared_preferences`. Keeps the call sites
/// testable by routing all access through a single class.
class LocalStorage {
  LocalStorage._(this._prefs);

  static Future<LocalStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalStorage._(prefs);
  }

  final SharedPreferences _prefs;

  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  String? getString(String key) => _prefs.getString(key);

  Future<bool> remove(String key) => _prefs.remove(key);

  Future<bool> clear() => _prefs.clear();
}
