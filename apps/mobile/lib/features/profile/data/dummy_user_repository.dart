import '../../../core/network/api_client.dart';
import '../domain/user_model.dart';
import 'user_repository.dart';

class DummyUserRepository implements UserRepository {
  UserModel _me = const UserModel(
    id: 'me',
    displayName: 'Alex Mercer',
    avatarAsset: 'assets/images/discovery/avatars/avatar_alex.png',
    rating: 4.9,
    bio: 'Love weekend runs and pickup basketball.',
    location: 'Auckland, NZ',
    activitiesCount: 24,
    hostedCount: 8,
    sports: [
      (sport: 'Basketball', level: 'Intermediate'),
      (sport: 'Running', level: 'Beginner'),
    ],
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
  Future<UserModel> updateProfile({String? displayName, String? bio}) async {
    _me = UserModel(
      id: _me.id,
      displayName: displayName ?? _me.displayName,
      avatarAsset: _me.avatarAsset,
      rating: _me.rating,
      bio: bio ?? _me.bio,
      location: _me.location,
      activitiesCount: _me.activitiesCount,
      hostedCount: _me.hostedCount,
      sports: _me.sports,
    );
    return _me;
  }
}

class RemoteUserRepository implements UserRepository {
  RemoteUserRepository({ApiClient? client, UserRepository? fallback})
    : _client = client ?? ApiClient.instance,
      _fallback = fallback ?? DummyUserRepository();

  final ApiClient _client;
  final UserRepository _fallback;

  @override
  Future<UserModel> me() async => _fallback.me();

  @override
  Future<UserModel?> byId(String id) async {
    try {
      final res = await _client.dio.get('/api/v1/users/$id');
      return _parse(res.data as Map<String, dynamic>);
    } catch (_) {
      return _fallback.byId(id);
    }
  }

  @override
  Future<UserModel> updateProfile({String? displayName, String? bio}) async {
    try {
      final res = await _client.dio.patch(
        '/api/v1/users/me',
        data: {'display_name': ?displayName, 'bio': ?bio},
      );
      return _parse(res.data as Map<String, dynamic>) ?? await _fallback.me();
    } catch (_) {
      return _fallback.updateProfile(displayName: displayName, bio: bio);
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
    );
  }
}
