import '../../activities/domain/place_suggestion.dart';

/// Read contract for venue autocomplete (`GET /api/places/autocomplete`).
abstract class PlacesRepository {
  /// Returns venue suggestions for [query]. Implementations should
  /// short-circuit on queries shorter than 3 characters — the backend
  /// does the same, but skipping the round-trip saves battery.
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    String? countryCodes,
  });
}
