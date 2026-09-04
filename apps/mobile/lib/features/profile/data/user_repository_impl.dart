import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../ratings/domain/rating_models.dart';
import '../domain/user_model.dart';
import 'user_repository.dart';


class LocalUserRepository implements UserRepository {
  UserModel _me = UserModel(
    id: 'me',
    displayName: 'Alex Mercer',
    avatarAsset: 'assets/images/discovery/avatars/avatar_alex.png',
    rating: 4.9,
    bio: 'Love weekend runs and pickup basketball.',
    location: 'Auckland, NZ',
    activitiesCount: 24,
    hostedCount: 8,
    sports: const [
      (sport: 'Basketball', level: 'Intermediate'),
      (sport: 'Running', level: 'Beginner'),
    ],
    ratingBySport: const {
      'Basketball': SportRatingSummary(average: 4.9, count: 12),
      'Running': SportRatingSummary(average: 4.7, count: 5),
      'Tennis': SportRatingSummary(average: 4.6, count: 3),
    },
    totalRatingCount: 20,
    email: 'alex.mercer@email.com',
    phone: '+64 21 555 0173',
    dateOfBirth: DateTime(1996, 3, 29),
    heightCm: 181,
    weightKg: 76,
    goal: 'Stay active with new sports',
  );

  static const _users = <UserModel>[
    UserModel(
      id: 'james',
      displayName: 'James Wilson',
      avatarAsset: 'assets/images/discovery/avatars/host_james.png',
      rating: 4.9,
      bio: 'Weekend warrior. Organizing pickup games since 2019.',
      location: 'New York, NY',
      activitiesCount: 24,
      hostedCount: 8,
      sports: [
        (sport: 'Basketball', level: 'Intermediate'),
        (sport: 'Tennis', level: 'Advanced'),
      ],
      ratingBySport: {
        'Basketball': SportRatingSummary(average: 4.9, count: 32),
        'Tennis': SportRatingSummary(average: 4.8, count: 14),
      },
      totalRatingCount: 46,
    ),
    UserModel(
      id: 'sarah',
      displayName: 'Sarah Chen',
      avatarAsset: 'assets/images/discovery/avatars/sarah_c.png',
      rating: 4.7,
      location: 'Auckland, NZ',
      activitiesCount: 12,
      hostedCount: 3,
      sports: [
        (sport: 'Tennis', level: 'Intermediate'),
        (sport: 'Volleyball', level: 'Beginner'),
      ],
      ratingBySport: {
        'Tennis': SportRatingSummary(average: 4.7, count: 9),
        'Volleyball': SportRatingSummary(average: 4.6, count: 4),
      },
      totalRatingCount: 13,
    ),
    UserModel(
      id: 'mike',
      displayName: 'Mike Chen',
      avatarAsset: 'assets/images/discovery/avatars/mike_c.png',
      rating: 4.5,
      location: 'Auckland, NZ',
      activitiesCount: 18,
      hostedCount: 5,
      sports: [(sport: 'Tennis', level: 'Advanced')],
      ratingBySport: {
        'Tennis': SportRatingSummary(average: 4.5, count: 22),
      },
      totalRatingCount: 22,
    ),
    UserModel(
      id: 'lisa',
      displayName: 'Lisa Park',
      avatarAsset: 'assets/images/discovery/avatars/lisa_p.png',
      rating: 4.8,
      location: 'Auckland, NZ',
      activitiesCount: 30,
      hostedCount: 12,
      sports: [
        (sport: 'Volleyball', level: 'Advanced'),
        (sport: 'Basketball', level: 'Beginner'),
      ],
      ratingBySport: {
        'Volleyball': SportRatingSummary(average: 4.8, count: 18),
        'Basketball': SportRatingSummary(average: 4.4, count: 6),
      },
      totalRatingCount: 24,
    ),
  ];

  @override
  Future<UserModel> me() async => _me;

  @override
  Future<UserModel?> byId(String id) async {
    if (id == _me.id || id == _me.displayName) return _me;
    return _users.cast<UserModel?>().firstWhere(
      (u) => u?.id == id || u?.displayName == id,
      orElse: () => null,
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
  }) async {
    _me = _me.copyWith(
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
    );
    return _me;
  }
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
      final userId = await SecureTokenStore.instance.readUserId();
      if (userId == null || userId.isEmpty) {
        debugPrint('[RemoteUserRepository.me] no stored userId — falling back');
        return _fallback.me();
      }
      final res = await _client.dio.get('/users/$userId');
      return _parse(res.data as Map<String, dynamic>) ?? await _fallback.me();
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
      final res = await _client.dio.get('/users/$id');
      return _parse(res.data as Map<String, dynamic>);
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
  }) async {
    try {
      final res = await _client.dio.patch(
        '/users/me',
        data: {
          'display_name': ?displayName,
          'bio': ?bio,
          'location': ?location,
          'email': ?email,
          'phone': ?phone,
          'date_of_birth': dateOfBirth?.toIso8601String(),
          'height_cm': ?heightCm,
          'weight_kg': ?weightKg,
          'goal': ?goal,
          if (sports != null)
            'sports': sports
                .map((s) => {'sport': s.sport, 'level': s.level})
                .toList(),
        },
      );
      return _parse(res.data as Map<String, dynamic>) ?? await _fallback.me();
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
      );
    }
  }

  UserModel? _parse(Map<String, dynamic>? json) {
    if (json == null) return null;
    return UserModel(
      id: json['id']?.toString() ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarAsset: json['avatar_asset'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      bio: json['bio'] as String?,
      location: json['location'] as String?,
      activitiesCount: json['activities_count'] as int? ?? 0,
      hostedCount: json['hosted_count'] as int? ?? 0,
      sports:
          (json['sports'] as List<dynamic>?)
              ?.map(
                (e) => (
                  sport: e['sport'] as String? ?? '',
                  level: e['level'] as String? ?? '',
                ),
              )
              .toList() ??
          const [],
      ratingBySport: _parseRatingBySport(json['rating_by_sport']),
      totalRatingCount: (json['total_rating_count'] as num?)?.toInt() ?? 0,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['date_of_birth'] != null
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
