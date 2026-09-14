import '../domain/place_suggestion.dart';
import 'places_repository.dart';

/// Offline-only places fallback. Returns no suggestions — venue
/// search always comes from the live backend proxy
/// (`GET /api/places/autocomplete`), never from bundled fixtures.
///
/// Kept as a class (rather than deleted) so widget tests can override
/// the provider without touching the network.
class LocalPlacesRepository implements PlacesRepository {
  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    String? countryCodes,
  }) async {
    return const [];
  }
}
