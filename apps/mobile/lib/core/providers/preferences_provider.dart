import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';
import '../utils/logger.dart';

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
    final storage = await LocalStorage.create();
    final raw = storage.getString(_kSportPrefs);
    if (raw == null) return;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      state = decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      // Corrupt data — start fresh.
      await storage.remove(_kSportPrefs);
    }
  }

  Future<void> _persist() async {
    try {
      final storage = await LocalStorage.create();
      await storage.setString(_kSportPrefs, json.encode(state));
    } catch (e) {
      logError('SportPreferences persist failed', e);
    }
  }

  Future<void> setSport(String sport, String level) async {
    state = {...state, sport: level};
    await _persist();
  }

  Future<void> removeSport(String sport) async {
    final updated = Map<String, String>.from(state)..remove(sport);
    state = updated;
    await _persist();
  }

  Future<void> setAll(Map<String, String> prefs) async {
    state = Map.unmodifiable(prefs);
    await _persist();
  }

  Future<void> reset() async {
    state = const {};
    await _persist();
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
    final storage = await LocalStorage.create();
    final v = storage.getDouble(_key);
    if (v != null) state = v;
  }

  void set(double value) {
    state = value;
    _persist(value);
  }

  Future<void> _persist(double value) async {
    try {
      final storage = await LocalStorage.create();
      await storage.setDouble(_key, value);
    } catch (e) {
      logError('DistanceFilter persist failed', e);
    }
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
    final storage = await LocalStorage.create();
    final v = storage.getString(_key);
    if (v != null) state = v;
  }

  void set(String value) {
    state = value;
    _persist(value);
  }

  Future<void> _persist(String value) async {
    try {
      final storage = await LocalStorage.create();
      await storage.setString(_key, value);
    } catch (e) {
      logError('PriceFilter persist failed', e);
    }
  }
}
