import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persists the user's sport + skill preferences so the discovery feed
/// and filter screen share the same source of truth.
///
/// Key: sport name (e.g. 'Basketball'), Value: skill level string.
/// Empty map = no filter (show all).
final sportPreferencesProvider =
    StateNotifierProvider<SportPreferencesNotifier, Map<String, String>>(
      (ref) => SportPreferencesNotifier(),
    );

class SportPreferencesNotifier extends StateNotifier<Map<String, String>> {
  SportPreferencesNotifier() : super(const {});

  void setSport(String sport, String level) {
    state = {...state, sport: level};
  }

  void removeSport(String sport) {
    final updated = Map<String, String>.from(state);
    updated.remove(sport);
    state = updated;
  }

  void setAll(Map<String, String> prefs) => state = Map.unmodifiable(prefs);

  void reset() => state = const {};
}

/// Distance filter in km — shared between preferences and filter screens.
final distanceFilterProvider = StateProvider<double>((ref) => 5);

/// Price preference: 'free', 'paid', 'both'.
final priceFilterProvider = StateProvider<String>((ref) => 'both');
