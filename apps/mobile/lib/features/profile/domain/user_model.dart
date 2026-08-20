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
  });
}
