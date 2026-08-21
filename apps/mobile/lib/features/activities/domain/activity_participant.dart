/// Domain model for a participant entry shown on the Activity Participants
/// screen. Kept distinct from [UserModel] (profile/domain/user_model.dart)
/// because this view needs activity-scoped fields — `joinedAt` and
/// `isOrganizer` are properties of the *membership*, not the person, and
/// don't belong on the user's own profile record.
class ActivityParticipant {
  const ActivityParticipant({
    required this.userId,
    required this.name,
    required this.avatarAsset,
    required this.skillLevel,
    required this.joinedAt,
    required this.isOrganizer,
    this.isCheckedIn = false,
  });

  final String userId;
  final String name;
  final String avatarAsset;
  final String skillLevel;
  final DateTime joinedAt;
  final bool isOrganizer;

  /// Whether the host has recorded this participant as checked in at the
  /// venue. Surfaced on the Manage Activity screen's roster.
  final bool isCheckedIn;
}
