import '../../ratings/domain/rating_models.dart';

/// Domain model representing an app user (host, participant, chat sender).
class UserModel {
  final String id;
  final String displayName;
  final String? avatarAsset;
  final String? avatarUrl;

  /// Legacy single-score rating used by the pre-rating-system profile
  /// stat card. New code should read `ratingBySport[activity.sportType]`
  /// for host cards so the value tracks the same sport the user is
  /// browsing. Kept nullable so existing screens that look up an unknown
  /// host (`james`, `sarah`, `mike`, `lisa` from seed data) still render.
  final double? rating;
  final String? bio;
  final String? location;

  /// Total activities this user has participated in.
  final int activitiesCount;

  /// Total activities this user has hosted.
  final int hostedCount;

  /// Sports + skill level pairs (e.g. `[('Basketball', 'Intermediate')]`).
  final List<({String sport, String level})> sports;

  /// General playing level (`beginner`/`intermediate`/`advanced`/`any`)
  /// from the user record. Used as the fallback badge on sport chips
  /// whose own level is empty (backend `preferredSports` carries names
  /// only).
  final String? skillLevel;

  /// Per-sport community rating aggregate. Keyed by sport type
  /// (e.g. `Basketball`). Pulled from the API response
  /// `users/{id}.ratingBySport` and exposed so discovery/host cards can
  /// show "★ 4.8 (12)" *for the sport the user is browsing* rather than
  /// a single blended average.
  ///
  /// Empty when the user has fewer than one completed-activity rating.
  final Map<String, SportRatingSummary> ratingBySport;

  /// Cumulative count across every sport — surfaced in profile screens as
  /// a single "(N ratings)" chip. Independent of [ratingBySport] keys so
  /// it works even if the backend returns just a count, no breakdown.
  final int totalRatingCount;

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
    this.skillLevel,
    this.ratingBySport = const {},
    this.totalRatingCount = 0,
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
    String? skillLevel,
    Map<String, SportRatingSummary>? ratingBySport,
    int? totalRatingCount,
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
      skillLevel: skillLevel ?? this.skillLevel,
      ratingBySport: ratingBySport ?? this.ratingBySport,
      totalRatingCount: totalRatingCount ?? this.totalRatingCount,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
    );
  }

  /// Returns the rating summary for a given sport, falling back to the
  /// legacy [rating] field for seed users that pre-date the rating system.
  /// Returns `null` when there is genuinely no data to display.
  SportRatingSummary? ratingFor(String sportType) {
    final keyed = ratingBySport[sportType];
    if (keyed != null && keyed.hasRatings) return keyed;
    if (rating != null && rating! > 0 && totalRatingCount > 0) {
      return SportRatingSummary(average: rating!, count: totalRatingCount);
    }
    return null;
  }
}
