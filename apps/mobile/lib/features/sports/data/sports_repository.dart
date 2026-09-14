import '../../../core/network/api_client.dart';
import '../domain/sport_config.dart';

/// Master sports config. Served by `GET /api/public/sports` (no auth —
/// sports config is non-sensitive) and curated in the admin web.
/// Screens always keep a hardcoded fallback: a failed fetch must never
/// empty a picker, it just keeps the last-known list.
abstract class SportsRepository {
  Future<List<SportConfig>> configs();
}

class RemoteSportsRepository implements SportsRepository {
  RemoteSportsRepository({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  @override
  Future<List<SportConfig>> configs() async {
    final res = await _client.dio.get('/public/sports');
    final rows = apiDataList(res.data)
        .whereType<Map>()
        .map((e) => SportConfig.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.id.isNotEmpty && c.name.isNotEmpty)
        .toList();
    rows.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return rows;
  }
}

/// No honest offline fallback exists for admin-curated config — callers
/// catch and fall back to their bundled list instead.
class UnavailableSportsRepository implements SportsRepository {
  @override
  Future<List<SportConfig>> configs() {
    throw UnimplementedError(
      'Sports config requires the live API (useRemoteApi must be true).',
    );
  }
}
