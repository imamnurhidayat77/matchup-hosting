/// Models for the post-activity community rating system.
///
/// Each completed activity prompts every participant to give a single
/// 1-5 star rating to each other participant they played with. The backend
/// keeps an aggregate per `<rateeUid, sportType>` pair so the discovery
/// card's "★ X.X (N games)" host row can show real, recent feedback.
library;

/// One rating submitted against a single other participant.
///
/// The activity-level `comment` is shared across all participant rows in
/// the current screen, so it is captured on the submit-level payload rather
/// than duplicated here.
class ParticipantRatingSubmission {
  const ParticipantRatingSubmission({required this.rateeUserId, required this.stars});

  /// Auth UID of the participant being rated.
  final String rateeUserId;

  /// 1-5 inclusive. UI must enforce the range before constructing.
  final int stars;
}

/// Full payload for one submission to the rating endpoint.
class ActivityRatingSubmission {
  const ActivityRatingSubmission({
    required this.activityId,
    required this.activitySportType,
    required this.participants,
    this.comment,
  });

  /// Activity being rated. Must already be in the `past` state.
  final String activityId;

  /// Sport taxonomy at the time of submission — keeps aggregate buckets
  /// stable even if the host later edits the activity.
  final String activitySportType;

  /// One entry per other participant (the rater is excluded — clients must
  /// drop themselves before submitting). Empty list is allowed for the
  /// early prototype; backend can ignore in that case.
  final List<ParticipantRatingSubmission> participants;

  /// Optional one-liner (<=200 chars on UI side). Server trims longer input.
  final String? comment;
}

/// Outcome of a submit attempt.
class RatingSubmissionResult {
  const RatingSubmissionResult({
    required this.accepted,
    required this.submittedAt,
    this.remoteError,
  });

  final bool accepted;

  /// When the rating was recorded (local clock if remote, server clock when
  /// available — clients should never branch on this value).
  final DateTime submittedAt;

  /// Populated when [accepted] is false so the screen can surface the
  /// server message or, in fallback mode, just say "saved offline".
  final String? remoteError;
}

/// Summary of aggregate rating for a user. Computed by the backend
/// (`ratingBySport[sport]` reduced to avg + count) and surfaced through
/// the user model so profile screens can render counts as well as score.
class SportRatingSummary {
  const SportRatingSummary({required this.average, required this.count});

  /// Running average across all completed activities the user played
  /// within [SportRatingSummary.sportType]. Null when the user has fewer
  /// than one rating — callers should render "—".
  final double average;

  /// Total ratings considered in [average]. Used to label "★ 4.8 (12)".
  final int count;

  bool get hasRatings => count > 0;
}

/// Roll-up of a user's ratings across every sport they have feedback for,
/// keyed by sport type (e.g. `Basketball`, `Tennis`). Lives on
/// [UserModel.ratingBySport] and the activity-feed's host row picks the
/// bucket matching `activity.sportType` to display.
typedef RatingBySport = Map<String, SportRatingSummary>;
