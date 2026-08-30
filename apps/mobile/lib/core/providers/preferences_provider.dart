import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Keys ─────────────────────────────────────────────────────────────────────

const _kSportPrefs = 'pref_sport_skills_v1';
const _kDistance = 'pref_distance_km_v1';
const _kPrice = 'pref_price_mode_v1';

// ─── Sport preferences ────────────────────────────────────────────────────────

/// Persists the user's sport + skill preferences so the discovery feed
/// and filter screen share the same source of truth.
///
/// Key: sport name (e.g. 'Basketball'), Value: skill level string.
/// Empty map = no filter (show all sports).
///
/// Values are stored as a JSON-encoded map in [SharedPreferences] under
/// [_kSportPrefs] so they survive app restarts and OS kills.
final sportPreferencesProvider =
    StateNotifierProvider<SportPreferencesNotifier, Map<String, String>>(
      (ref) => SportPreferencesNotifier(),
    );

class SportPreferencesNotifier extends StateNotifier<Map<String, String>> {
  SportPreferencesNotifier() : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSportPrefs);
    if (raw == null) return;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      state = decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      // Corrupt data — start fresh.
      await prefs.remove(_kSportPrefs);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSportPrefs, json.encode(state));
  }

  void setSport(String sport, String level) {
    state = {...state, sport: level};
    _persist();
  }

  void removeSport(String sport) {
    final updated = Map<String, String>.from(state)..remove(sport);
    state = updated;
    _persist();
  }

  void setAll(Map<String, String> prefs) {
    state = Map.unmodifiable(prefs);
    _persist();
  }

  void reset() {
    state = const {};
    _persist();
  }
}

// ─── Distance filter ──────────────────────────────────────────────────────────

/// Discovery distance in km — shared between preferences and filter screens.
/// Persisted to [SharedPreferences] so the last chosen radius survives restart.
final distanceFilterProvider =
    StateNotifierProvider<_DoubleNotifier, double>(
      (ref) => _DoubleNotifier(_kDistance, 5),
    );

class _DoubleNotifier extends StateNotifier<double> {
  _DoubleNotifier(this._key, double defaultValue) : super(defaultValue) {
    _load(defaultValue);
  }

  final String _key;

  Future<void> _load(double fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_key);
    if (v != null) state = v;
  }

  void set(double value) {
    state = value;
    SharedPreferences.getInstance().then((p) => p.setDouble(_key, value));
  }
}

// ─── Price filter ─────────────────────────────────────────────────────────────

/// Price preference: 'free' | 'paid' | 'both'.
/// Persisted to [SharedPreferences].
final priceFilterProvider =
    StateNotifierProvider<_StringNotifier, String>(
      (ref) => _StringNotifier(_kPrice, 'both'),
    );

class _StringNotifier extends StateNotifier<String> {
  _StringNotifier(this._key, String defaultValue) : super(defaultValue) {
    _load(defaultValue);
  }

  final String _key;

  Future<void> _load(String fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v != null) state = v;
  }

  void set(String value) {
    state = value;
    SharedPreferences.getInstance().then((p) => p.setString(_key, value));
  }
}
