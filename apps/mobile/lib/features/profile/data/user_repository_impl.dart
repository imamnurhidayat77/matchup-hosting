import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../ratings/domain/rating_models.dart';
import '../domain/user_model.dart';
import 'user_repository.dart';


/// Offline-only user store. Same contract as
/// [LocalActivityRepository]: every read returns empty data, every
/// write throws. The app **always** talks to the live backend.
class LocalUserRepository implements UserRepository {
  @override
  Future<UserModel> me() async {
    throw StateError(
      'UserRepository.me() requires a live backend — no offline '
      'fallback is provided.',
    );
  }

  @override
  Future<UserModel?> byId(String id) async {
    return null;
  }

  @override
  Future<UserModel> uploadAvatar({required String localPath}) {
    throw StateError(
      'UserRepository.uploadAvatar() requires a live backend — no offline '
      'fallback is provided.',
    );
  }

  @override
  Future<UserModel> updateProfile({
    String? displayName,
    String? bio,
    String? location,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    int? heightCm,
    int? weightKg,
    String? goal,
    List<({String sport, String level})>? sports,
    String? joinReason,
  }) async {
    throw StateError(
      'UserRepository.updateProfile() requires a live backend — no '
      'offline fallback is provided.',
    );
  }
}

/// Normalises a UI skill label ('Beginner') to the backend wire value
/// ('beginner'). Returns null when there is no usable level, so the
/// caller can omit it instead of persisting a bogus value.
String? wireSkillLevel(String level) {
  final v = level.trim().toLowerCase();
  return switch (v) {
    'beginner' || 'intermediate' || 'advanced' || 'any' => v,
    _ => null,
  };
}

/// Most frequent wire level across [sports]; ties resolve to the
/// first-seen level. Null when no sport carries a usable level.
String? dominantSkillLevel(List<({String sport, String level})> sports) {
  final counts = <String, int>{};
  final order = <String>[];
  for (final s in sports) {
    final wire = wireSkillLevel(s.level);
    if (wire == null) continue;
    counts[wire] = (counts[wire] ?? 0) + 1;
    if (!order.contains(wire)) order.add(wire);
  }
  String? best;
  var bestCount = 0;
  for (final wire in order) {
    if (counts[wire]! > bestCount) {
      best = wire;
      bestCount = counts[wire]!;
    }
  }
  return best;
}

/// Maps a backend wire level ('beginner') back to the UI label
/// ('Beginner') used by the sport preference providers.
String labelSkillLevel(String? wire) {
  return switch (wire?.trim().toLowerCase()) {
    'beginner' => 'Beginner',
    'advanced' => 'Advanced',
    'any' => 'Any',
    _ => 'Intermediate',
  };
}

class RemoteUserRepository implements UserRepository {
  RemoteUserRepository({ApiClient? client, UserRepository? fallback})
    : _client = client ?? ApiClient.instance,
      _fallback = fallback ?? LocalUserRepository();

  final ApiClient _client;
  final UserRepository _fallback;

  @override
  Future<UserModel> me() async {
    try {
      // `/users/me` is the canonical "current authenticated user" endpoint.
      // The auth middleware resolves the uid from the Bearer token, so we
      // don't need to pass an id — passing the auth uid would have hit the
      // public-profile route instead and returned a smaller payload.
      final res = await _client.dio.get('/users/me');
      return _parse(apiDataMap(res.data)) ?? await _fallback.me();
    } on DioException catch (e) {
      debugPrint('[RemoteUserRepository.me] DioException ${e.response?.statusCode}: ${e.message}');
      return _fallback.me();
    } catch (e) {
      debugPrint('[RemoteUserRepository.me] unexpected: $e');
      return _fallback.me();
    }
  }

  @override
  Future<UserModel?> byId(String id) async {
    try {
      // Public profile route is `/users/:uid/profile` per the backend.
      final res = await _client.dio.get('/users/$id/profile');
      return _parse(apiDataMap(res.data));
    } catch (_) {
      return _fallback.byId(id);
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? displayName,
    String? bio,
    String? location,
    String? email,
    String? phone,
    DateTime? dateOfBirth,
    int? heightCm,
    int? weightKg,
    String? goal,
    List<({String sport, String level})>? sports,
    String? joinReason,
  }) async {
    try {
      // The backend's `editableProfileFields` is strict — any other key
      // returns INVALID_INPUT. The mobile model has more fields than the
      // backend currently persists (`email`, `phone`, `heightCm`,
      // `weightKg`, `goal`); we intentionally omit them from the PATCH
      // body until backend support lands. The local fallback still records
      // them in memory so the Edit Profile screen keeps working offline.
      //
      // Mapping:
      //   - `location`  → `preferredLocations[0]` (backend stores an array)
      //   - `sports`    → `preferredSports` (sport names) +
      //                  `sportSkillLevels` (per-sport wire levels) +
      //                  `skillLevel` (dominant level — feeds the
      //                  profile-completed check and the public profile)
      //   - `joinReason`→ `joinReason` (onboarding answer, private)
      final dominant = sports != null && sports.isNotEmpty
          ? dominantSkillLevel(sports)
          : null;
      final levelEntries = sports != null
          ? [
              for (final s in sports)
                if (wireSkillLevel(s.level) != null)
                  MapEntry(s.sport, wireSkillLevel(s.level)!),
            ]
          : const <MapEntry<String, String>>[];
      final res = await _client.dio.patch(
        '/users/me',
        data: {
          if (displayName != null && displayName.isNotEmpty)
            'displayName': displayName,
          if (bio != null && bio.isNotEmpty) 'bio': bio,
          if (location != null && location.isNotEmpty)
            'preferredLocations': [location],
          if (dateOfBirth != null)
            'dateOfBirth': dateOfBirth.toIso8601String().split('T').first,
          if (sports != null && sports.isNotEmpty)
            'preferredSports': sports.map((s) => s.sport).toList(),
          if (levelEntries.isNotEmpty)
            'sportSkillLevels': Map.fromEntries(levelEntries),
          if (dominant case final skill) 'skillLevel': skill,
          if (joinReason != null && joinReason.trim().isNotEmpty)
            'joinReason': joinReason.trim(),
        },
      );
      return _parse(apiDataMap(res.data)) ?? await _fallback.me();
    } catch (_) {
      return _fallback.updateProfile(
        displayName: displayName,
        bio: bio,
        location: location,
        email: email,
        phone: phone,
        dateOfBirth: dateOfBirth,
        heightCm: heightCm,
        weightKg: weightKg,
        goal: goal,
        sports: sports,
        joinReason: joinReason,
      );
    }
  }

  @override
  Future<UserModel> uploadAvatar({required String localPath}) async {
    // The backend (`PATCH /users/me/photo`) requires the Storage path
    // to be `users/{uid}/profile/…` and stores both path and URL.
    final uid = await SecureTokenStore.instance.readUserId();
    if (uid == null || uid.isEmpty) {
      throw StateError('No signed-in user for profile photo upload.');
    }
    final basename = localPath.split('/').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uploaded = await StorageService.instance.uploadToPath(
      localPath: localPath,
      storagePath: 'users/$uid/profile/$timestamp-$basename',
    );
    if (uploaded == null || uploaded.downloadUrl.isEmpty) {
      throw StateError('Profile photo upload failed.');
    }
    final res = await _client.dio.patch(
      '/users/me/photo',
      data: {'photoPath': uploaded.path, 'photoUrl': uploaded.downloadUrl},
    );
    final updated = _parse(apiDataMap(res.data));
    if (updated == null) {
      throw StateError('Profile photo update was not acknowledged.');
    }
    return updated;
  }

  UserModel? _parse(Map<String, dynamic>? json) {
    if (json == null) return null;
    // Backend returns `preferredSports` as a list of sport-name strings
    // plus `sportSkillLevels` (`{ Tennis: 'intermediate' }`) with the
    // per-sport wire levels. The mobile model expects a list of
    // `(sport, level)` records where level is used to render the
    // per-sport badge on the profile screen — levels map back to UI
    // labels, falling back to '' (renders the bare chip) when unknown.
    final preferredSports = json['preferredSports'] as List<dynamic>?;
    final skillMap = json['sportSkillLevels'] as Map?;
    final mappedSports = preferredSports != null
        ? preferredSports.map((sport) {
            final name = sport.toString();
            final wire = skillMap?[name]?.toString();
            return (
              sport: name,
              level: wire != null && wire.isNotEmpty
                  ? labelSkillLevel(wire)
                  : '',
            );
          }).toList()
        : (json['sports'] as List<dynamic>?)
              ?.map(
                (e) => (
                  sport: e['sport']?.toString() ?? '',
                  level: e['level']?.toString() ?? '',
                ),
              )
              .toList();

    return UserModel(
      id: json['id']?.toString() ?? json['authUid']?.toString() ?? '',
      displayName: json['displayName'] as String? ??
          json['display_name'] as String? ??
          '',
      avatarAsset: json['avatar_asset'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      bio: json['bio'] as String?,
      location: (json['preferredLocations'] as List?)?.isNotEmpty == true
          ? (json['preferredLocations'] as List).first.toString()
          : json['location'] as String?,
      activitiesCount:
          (json['activitiesCount'] as num?)?.toInt() ??
          (json['activities_count'] as num?)?.toInt() ??
          0,
      hostedCount:
          (json['hostedCount'] as num?)?.toInt() ??
          (json['hosted_count'] as num?)?.toInt() ??
          0,
      sports: mappedSports ?? const [],
      skillLevel: json['skillLevel'] as String? ??
          json['skill_level'] as String?,
      ratingBySport: _parseRatingBySport(
        json['ratingBySport'] ?? json['rating_by_sport'],
      ),
      totalRatingCount:
          (json['totalRatingCount'] as num?)?.toInt() ??
          (json['total_rating_count'] as num?)?.toInt() ??
          0,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'] as String)
          : null,
      heightCm: json['height_cm'] as int?,
      weightKg: json['weight_kg'] as int?,
      goal: json['goal'] as String?,
    );
  }

  /// Decodes the API's per-sport rating map. The shape is
  /// `{ "Basketball": { "average": 4.7, "count": 12 } }`.
  Map<String, SportRatingSummary> _parseRatingBySport(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.entries
        .where((e) => e.value is Map)
        .map(
          (e) => MapEntry<String, SportRatingSummary>(
            e.key.toString(),
            SportRatingSummary(
              average: ((e.value as Map)['average'] as num?)?.toDouble() ?? 0,
              count: ((e.value as Map)['count'] as num?)?.toInt() ?? 0,
            ),
          ),
        )
        .where((e) => e.value.hasRatings)
        .fold<Map<String, SportRatingSummary>>(
          <String, SportRatingSummary>{},
          (acc, e) => acc..[e.key] = e.value,
        );
  }
}
