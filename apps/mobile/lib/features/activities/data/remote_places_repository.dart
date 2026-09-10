import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../domain/place_suggestion.dart';
import 'places_repository.dart';

/// HTTP-backed [PlacesRepository]. Hits the api-server proxy (which
/// fronts OpenStreetMap's Nominatim) — the mobile never talks to the
/// geocoder directly, so provider swaps don't need an app update.
class RemotePlacesRepository implements PlacesRepository {
  RemotePlacesRepository({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    String? countryCodes,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const <PlaceSuggestion>[];

    try {
      final res = await _client.dio.get(
        '/places/autocomplete',
        queryParameters: {
          'q': trimmed,
          if (countryCodes != null && countryCodes.isNotEmpty)
            'countryCodes': countryCodes,
        },
      );
      return apiDataList(res.data)
          .whereType<Map<String, dynamic>>()
          .map(PlaceSuggestion.fromJson)
          .toList();
    } catch (e, st) {
      debugPrint('[RemotePlacesRepository.autocomplete] $e\n$st');
      return const <PlaceSuggestion>[];
    }
  }
}
