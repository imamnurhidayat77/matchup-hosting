/// Domain model representing an app user (host, participant, chat sender).
class UserModel {
  final String id;
  final String displayName;
  final String? avatarAsset;
  final String? avatarUrl;
  final double? rating;
  final String? bio;
  final String? location;

  /// Total activities this user has participated in.
  final int activitiesCount;

  /// Total activities this user has hosted.
  final int hostedCount;

  /// Sports + skill level pairs (e.g. `[('Basketball', 'Intermediate')]`).
  final List<({String sport, String level})> sports;

  // ─── Fields editable from Edit Profile (PRD Section 2.3) ────────────────
  // These used to be string literals hardcoded in the screen's
  // `_initFields`. Now they live on the model so Edit Profile reads real
  // data and persists real changes via `UserRepository.updateProfile`.
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;
  final int? heightCm;
  final int? weightKg;
  final String? goal;

  const UserModel({
    required this.id,
    required this.displayName,
    this.avatarAsset,
    this.avatarUrl,
    this.rating,
    this.bio,
    this.location,
    this.activitiesCount = 0,
    this.hostedCount = 0,
    this.sports = const [],
    this.email,
    this.phone,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.goal,
  });

  UserModel copyWith({
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
  }) {
    return UserModel(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarAsset: avatarAsset,
      avatarUrl: avatarUrl,
      rating: rating,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      activitiesCount: activitiesCount,
      hostedCount: hostedCount,
      sports: sports ?? this.sports,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
    );
  }
}
