/// Domain model for a participant entry shown on the Activity Participants
/// screen. Kept distinct from [UserModel] (profile/domain/user_model.dart)
/// because this view needs activity-scoped fields — `joinedAt` and
/// `isOrganizer` are properties of the *membership*, not the person, and
/// don't belong on the user's own profile record.
class ActivityParticipant {
  const ActivityParticipant({
    required this.userId,
    required this.name,
    this.avatarAsset,
    required this.skillLevel,
    required this.joinedAt,
    required this.isOrganizer,
    this.isCheckedIn = false,
    this.avatarUrl,
  });

  final String userId;
  final String name;

  /// Bundled asset filename (e.g. `'avatar_1.png'`) for legacy payloads
  /// only. Always null for live backend data — renderers must prefer
  /// [avatarUrl] and fall back to initials, never to a stock face.
  final String? avatarAsset;
  final String skillLevel;
  final DateTime joinedAt;
  final bool isOrganizer;

  /// Whether the host has recorded this participant as checked in at the
  /// venue. Surfaced on the Manage Activity screen's roster.
  final bool isCheckedIn;

  /// Remote photo URL from the backend profile (`photoUrl`), if the user
  /// uploaded one. Takes precedence over [avatarAsset] at render time.
  final String? avatarUrl;
}
