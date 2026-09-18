/// Domain model for a sports activity card displayed in the discovery feed.
class ActivityModel {
  final String id;
  final String title;
  final String sportType;
  final String description;

  /// Venue name — the primary location line (e.g. `Brooklyn Public Courts`).
  final String location;

  /// Street-level address shown beneath [location] on the detail screen
  /// (e.g. `Court #3, Prospect Park, NY`). When null the UI falls back to
  /// showing [distanceKm] instead, so the second line is never blank.
  final String? addressLine;

  final double distanceKm;
  final DateTime dateTime;
  final String skillLevel;
  final int capacity;
  final int participantCount;
  final String hostName;
  final String? coverImageUrl;
  final ActivityStatus status;

  /// How long the activity runs, in minutes. Defaults to 120 (2h) — the same
  /// assumption the detail screen used to hardcode as `start + 2h` before
  /// this field existed. Create Activity now captures it explicitly via a
  /// Duration segmented control (1h / 1.5h / 2h / 3h — PRD Section 1.4).
  final int durationMinutes;

  /// Whether joining costs money. Drives the Free/Paid chip on the discovery
  /// card. Defaults to false (Free) since most pickup games are.
  final bool isPaid;

  /// Joining fee amount, set only when [isPaid] is true. Null for free
  /// games and for payloads written before the field existed.
  ///
  /// Semantics depend on [feeMode]: `fixed` = price per person,
  /// `split` = worst-case price per person (`totalCost / minPlayers`).
  /// Old clients ignore the mode and just render this number, so every
  /// write path must keep it populated.
  final double? fee;

  /// Pricing mode for paid games: `'fixed'` (flat price per person,
  /// the default) or `'split'` (total venue cost shared among players).
  /// Defaults to fixed for payloads written before the field existed.
  final String feeMode;

  /// Total cost to split (venue booking etc.), set only for `split`
  /// mode. Null otherwise.
  final double? totalCost;

  /// Minimum players the host needs for the game to run. Only
  /// meaningful for `split` mode — the displayed per-person price is
  /// `totalCost / minPlayers` (worst case; cheaper when full).
  /// Null means "full capacity".
  final int? minPlayers;

  /// Host's average rating (0–5) for this activity's sport, read from
  /// `hostProfile.ratingBySport[sportType]` which the backend maintains
  /// on every rating submit — plus the number of games they've hosted.
  /// Null when the host has no ratings yet (UI shows "New host").
  /// Never a placeholder: there is no fake 4.8 anywhere in this app.
  final double? hostRating;
  final int hostGamesCount;

  /// Short atmosphere/expectation tags shown as small chips ("Friendly
  /// people", "Great vibes", "Arrive 15m early"). Purely descriptive.
  final List<String> vibeTags;

  /// Backend viewer context (see `ActivityViewerContext` in the api
  /// server). `isHost` / `isParticipant` say whether the signed-in
  /// user hosts or joined this activity; `mySwipeDecision` is the
  /// user's swipe (`'join'`, `'pass'`, or null when unswiped).
  final bool isParticipant;
  final bool isHost;
  final String? mySwipeDecision;

  /// Backend host uid (`ActivityRecord.hostId`). Used for host-only
  /// actions and "message host" flows.
  final String hostId;

  /// Raw venue coordinates from the backend. Nullable because seed-era
  /// and hand-built payloads (including this model's own legacy
  /// fixtures) don't carry them — repositories fill [distanceKm] from
  /// these when a device location is available.
  final double? latitude;
  final double? longitude;

  /// How new members get in (`ActivityRecord.joinPolicy`): `'open'`
  /// means instant join, `'approval'` parks the user in a pending join
  /// request. Defaults to open for payloads written before the field
  /// existed — same default the backend applies.
  final String joinPolicy;

  /// The viewer's join-request state on approval-gated activities
  /// (`'none'`, `'pending'`, `'approved'`, `'declined'`). Null when the
  /// backend didn't send viewer context (e.g. hand-built fixtures).
  final String? joinRequestStatus;

  /// Denormalized count of pending join requests
  /// (`ActivityRecord.pendingRequestCount`). Drives the public "N
  /// waiting" display on approval-gated activities. Defaults to 0 for
  /// payloads written before the field existed.
  final int pendingRequestCount;

  /// Raw backend lifecycle string (`open` / `full` / `cancelled` /
  /// `completed` / `removed`) as sent in `json['status']`, preserved
  /// verbatim. [status] collapses `cancelled` / `completed` / `removed`
  /// all into [ActivityStatus.past] (and viewer context then overrides to
  /// `hosted` / `joined`), so without this field the UI cannot tell a
  /// cancelled game from a completed one. Empty when the payload carried
  /// no status (e.g. hand-built fixtures).
  final String lifecycleStatus;

  const ActivityModel({
    required this.id,
    required this.title,
    required this.sportType,
    required this.description,
    required this.location,
    this.addressLine,
    required this.distanceKm,
    required this.dateTime,
    required this.skillLevel,
    required this.capacity,
    required this.participantCount,
    required this.hostName,
    this.coverImageUrl,
    this.status = ActivityStatus.available,
    this.durationMinutes = 120,
    this.isPaid = false,
    this.fee,
    this.feeMode = 'fixed',
    this.totalCost,
    this.minPlayers,
    this.hostRating,
    this.hostGamesCount = 0,
    this.vibeTags = const ['Friendly people', 'Great vibes'],
    this.isParticipant = false,
    this.isHost = false,
    this.mySwipeDecision,
    this.hostId = '',
    this.latitude,
    this.longitude,
    this.joinPolicy = 'open',
    this.joinRequestStatus,
    this.pendingRequestCount = 0,
    this.lifecycleStatus = '',
  });

  /// The activity's end time, derived from [dateTime] + [durationMinutes].
  DateTime get endTime => dateTime.add(Duration(minutes: durationMinutes));

  /// Compact duration label for the discovery card meta row, e.g. `~2h`,
  /// `~1.5h`, `~45m`.
  String get durationLabel {
    if (durationMinutes % 60 == 0) return '~${durationMinutes ~/ 60}h';
    if (durationMinutes > 60) {
      return '~${(durationMinutes / 60).toStringAsFixed(1)}h';
    }
    return '~${durationMinutes}m';
  }

  /// True when the game splits a total cost instead of charging a
  /// flat per-person price.
  bool get isSplitCost => isPaid && feeMode == 'split';

  /// Per-person price the joiner sees. Fixed mode: [fee] as-is.
  /// Split mode: worst case (`totalCost / minPlayers`, or full capacity
  /// when no minimum set) — the game only gets cheaper from here.
  double? get displayFee {
    if (!isPaid) return null;
    if (!isSplitCost) return fee;
    if (totalCost == null) return fee;
    final divisor = (minPlayers ?? capacity).clamp(1, 1000);
    return totalCost! / divisor;
  }

  /// Short price label for detail rows, e.g. `$10.00 /person` or
  /// `≈$12.50 /person · split`. Null when free or amount unknown.
  String? get feeLabel {
    final amount = displayFee;
    if (amount == null) return null;
    final formatted = '\$${amount.toStringAsFixed(2)} /person';
    return isSplitCost ? '≈$formatted · split' : formatted;
  }

  /// One-line split explainer for detail screens, e.g.
  /// `Total $60 · min 4 · max $15 each, cheaper when full`.
  /// Null when not split or total unknown.
  String? get splitExplainer {
    if (!isSplitCost || totalCost == null) return null;
    final min = minPlayers ?? capacity;
    final worst = displayFee;
    final total = '\$${totalCost!.toStringAsFixed(totalCost! == totalCost!.roundToDouble() ? 0 : 2)}';
    final each = worst != null ? '\$${worst.toStringAsFixed(2)}' : '—';
    return 'Total $total · min $min · max $each each, cheaper when full';
  }

  ActivityModel copyWith({
    String? title,
    String? sportType,
    String? description,
    String? location,
    String? addressLine,
    double? distanceKm,
    DateTime? dateTime,
    String? skillLevel,
    int? capacity,
    String? hostName,
    String? coverImageUrl,
    int? durationMinutes,
    bool? isPaid,
    double? hostRating,
    int? hostGamesCount,
    List<String>? vibeTags,
    String? lifecycleStatus,
    ActivityStatus? status,
    int? participantCount,
    bool? isParticipant,
    bool? isHost,
    String? mySwipeDecision,
    String? hostId,
    double? latitude,
    double? longitude,
    String? joinPolicy,
    String? joinRequestStatus,
    double? fee,
    String? feeMode,
    double? totalCost,
    int? minPlayers,
    int? pendingRequestCount,
  }) {
    return ActivityModel(
      id: id,
      title: title ?? this.title,
      sportType: sportType ?? this.sportType,
      description: description ?? this.description,
      location: location ?? this.location,
      addressLine: addressLine ?? this.addressLine,
      distanceKm: distanceKm ?? this.distanceKm,
      dateTime: dateTime ?? this.dateTime,
      skillLevel: skillLevel ?? this.skillLevel,
      capacity: capacity ?? this.capacity,
      participantCount: participantCount ?? this.participantCount,
      hostName: hostName ?? this.hostName,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      status: status ?? this.status,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isPaid: isPaid ?? this.isPaid,
      fee: fee ?? this.fee,
      feeMode: feeMode ?? this.feeMode,
      totalCost: totalCost ?? this.totalCost,
      minPlayers: minPlayers ?? this.minPlayers,
      hostRating: hostRating ?? this.hostRating,
      hostGamesCount: hostGamesCount ?? this.hostGamesCount,
      vibeTags: vibeTags ?? this.vibeTags,
      isParticipant: isParticipant ?? this.isParticipant,
      isHost: isHost ?? this.isHost,
      mySwipeDecision: mySwipeDecision ?? this.mySwipeDecision,
      hostId: hostId ?? this.hostId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      joinRequestStatus: joinRequestStatus ?? this.joinRequestStatus,
      pendingRequestCount: pendingRequestCount ?? this.pendingRequestCount,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
    );
  }

  bool get isFull => capacity > 0 && participantCount >= capacity;
  bool get isAlmostFull => participantCount >= (capacity * 0.8).ceil();

  int get spotsLeft => (capacity - participantCount).clamp(0, capacity);

  /// True when newcomers must be approved by the host instead of
  /// joining instantly.
  bool get requiresApproval => joinPolicy == 'approval';

  /// True once the start time has passed. Joining/requesting is
  /// server-cut off at this point, so the UI disables join actions
  /// instead of letting the backend 409.
  bool get hasStarted => !dateTime.isAfter(DateTime.now());

  /// True when this activity's chat is read-only archived. Archived once
  /// the activity is past its end by more than the 7-day grace window
  /// (`CHAT_ARCHIVE_GRACE_MS` on the backend). History stays readable,
  /// writes stop.
  bool get isChatArchived {
    if (status == ActivityStatus.past) {
      final threshold = DateTime.now().subtract(const Duration(days: 7));
      return endTime.isBefore(threshold);
    }
    return false;
  }

  /// True when the viewer already has a pending request on an
  /// approval-gated activity.
  bool get hasPendingRequest => joinRequestStatus == 'pending';

  /// Serialises to the API wire format (snake_case).
  /// Used by [RemoteActivityRepository] for request bodies and
  /// as the canonical JSON representation of this model.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sport_type': sportType,
      'description': description,
      'location': location,
      'address_line': addressLine,
      'distance_km': distanceKm,
      'date_time': dateTime.toIso8601String(),
      'skill_level': skillLevel,
      'capacity': capacity,
      'participant_count': participantCount,
      'host_name': hostName,
      'cover_image_url': coverImageUrl,
      'status': status.name,
      'duration_minutes': durationMinutes,
      'is_paid': isPaid,
      'fee': fee,
      'fee_mode': feeMode,
      'total_cost': totalCost,
      'min_players': minPlayers,
      'host_rating': hostRating,
      'host_games_count': hostGamesCount,
      'vibe_tags': vibeTags,
      'is_participant': isParticipant,
      'is_host': isHost,
      'my_swipe_decision': mySwipeDecision,
      'host_id': hostId,
      'latitude': latitude,
      'longitude': longitude,
      'join_policy': joinPolicy,
      'join_request_status': joinRequestStatus,
      'pending_request_count': pendingRequestCount,
    };
  }

  /// Deserialises from an API response map.
  ///
  /// Accepts **both** the snake_case format used by the mobile app's own
  /// [toJson] and the camelCase format returned by the backend
  /// (`sportType`, `locationName`, `startTime`, `coverImageUrl`, etc.).
  /// The backend's [ActivityWithId] wraps the host profile under
  /// `hostProfile.displayName` — that nested object is flattened to
  /// [hostName] here so downstream code can stay schema-agnostic.
  ///
  /// If `startTime` and `endTime` are both present, [durationMinutes] is
  /// computed from their difference; otherwise it falls back to whatever
  /// `duration_minutes` / `durationMinutes` the payload carries, and
  /// finally to the 120-minute default.
  ///
  /// All [RemoteActivityRepository] methods call this instead of
  /// maintaining their own private `_parse` — one parsing path, one place
  /// to update.
  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    final startRaw = json['startTime'] as String? ?? json['date_time'] as String?;
    final endRaw = json['endTime'] as String? ?? json['end_time'] as String?;

    // Backend sends UTC ISO (`Z`); convert to device-local ONCE here so
    // every downstream formatter renders correct local times with no
    // per-site `.toLocal()` calls.
    // Unparseable start falls back to a far-future sentinel (NOT now) so
    // corrupt rows sort last in soonest-first lists instead of
    // masquerading as starting-now ghost live cards.
    final start =
        DateTime.tryParse(startRaw ?? '')?.toLocal() ?? DateTime(2100);
    final end = endRaw == null ? null : DateTime.tryParse(endRaw)?.toLocal();

    int resolvedDuration;
    if (end != null && end.isAfter(start)) {
      resolvedDuration = end.difference(start).inMinutes;
    } else {
      resolvedDuration = (json['duration_minutes'] as num?)?.toInt() ??
          (json['durationMinutes'] as num?)?.toInt() ??
          120;
    }

    // Backend returns host info under a nested `hostProfile` object.
    // Fall back to flat `hostName` / `host_name` for older payloads.
    final hostProfile = json['hostProfile'] as Map<String, dynamic>?;
    final hostName = hostProfile?['displayName'] as String? ??
        json['host_name'] as String? ??
        json['hostName'] as String? ??
        '';

    // Viewer context straight from the backend (`ActivityViewerContext`).
    // Accepts both camelCase and the snake_case form this model's own
    // [toJson] emits so round-trips stay lossless.
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final isHost =
        json['isHost'] as bool? ?? json['is_host'] as bool? ?? false;
    final isParticipant = json['isParticipant'] as bool? ??
        json['is_participant'] as bool? ??
        false;
    final mySwipeDecision = json['mySwipeDecision'] as String? ??
        json['my_swipe_decision'] as String?;

    // Backend lifecycle states (`open`/`full`/`cancelled`/`completed`/
    // `removed`) map onto the mobile enum; the viewer's relationship
    // then wins — a host always sees `hosted`, a joiner always sees
    // `joined`, regardless of lifecycle. The raw string is preserved on
    // [lifecycleStatus] so the UI can still tell cancelled apart from
    // completed.
    final rawLifecycle = json['status']?.toString() ?? '';
    final sport =
        json['sportType'] as String? ?? json['sport_type'] as String? ?? '';
    var status = _statusFromString(json['status'] as String?);
    if (isHost) {
      status = ActivityStatus.hosted;
    } else if (isParticipant) {
      status = ActivityStatus.joined;
    }

    return ActivityModel(
      id: json['id']?.toString() ?? json['activityId']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      sportType: sport,
      description: json['description'] as String? ?? '',
      location:
          json['locationName'] as String? ?? json['location'] as String? ?? '',
      addressLine: json['address'] as String? ?? json['address_line'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      dateTime: start,
      skillLevel:
          json['skillLevel'] as String? ?? json['skill_level'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 10,
      participantCount: (json['participantCount'] as num?)?.toInt() ??
          (json['participant_count'] as num?)?.toInt() ??
          0,
      hostName: hostName,
      coverImageUrl: json['coverImageUrl'] as String? ??
          json['cover_image_url'] as String?,
      status: status,
      durationMinutes: resolvedDuration,
      isPaid: json['is_paid'] as bool? ?? json['isPaid'] as bool? ?? false,
      fee: (json['fee'] as num?)?.toDouble(),
      feeMode: _feeModeFromString(
          json['fee_mode'] as String? ?? json['feeMode'] as String?),
      totalCost: (json['total_cost'] as num?)?.toDouble() ??
          (json['totalCost'] as num?)?.toDouble(),
      minPlayers: (json['min_players'] as num?)?.toInt() ??
          (json['minPlayers'] as num?)?.toInt(),
      hostRating: _hostRatingFor(json, sport),
      hostGamesCount: _hostGamesFor(json),
      vibeTags:
          (json['vibe_tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      isParticipant: isParticipant,
      isHost: isHost,
      mySwipeDecision: mySwipeDecision,
      hostId: json['hostId']?.toString() ?? json['host_id']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      joinPolicy: json['joinPolicy'] as String? ?? json['join_policy'] as String? ?? 'open',
      joinRequestStatus: json['joinRequestStatus'] as String? ??
          json['join_request_status'] as String?,
      pendingRequestCount: (json['pendingRequestCount'] as num?)?.toInt() ??
          (json['pending_request_count'] as num?)?.toInt() ??
          0,
      lifecycleStatus: rawLifecycle,
    );
  }

  static String _feeModeFromString(String? s) => switch (s) {
        'split' => 'split',
        _ => 'fixed',
      };

  /// Real host rating for [sport] from `hostProfile.ratingBySport`
  /// (`{average, count}` per sport, maintained server-side on every
  /// rating submit). Null when the host has no ratings for the sport —
  /// callers render "New host". The flat `host_rating` fallback only
  /// exists for this model's own [toJson] round-trips.
  static double? _hostRatingFor(Map<String, dynamic> json, String sport) {
    final profile = json['hostProfile'];
    final buckets = profile is Map<String, dynamic>
        ? profile['ratingBySport']
        : null;
    final bucket = buckets is Map<String, dynamic> && sport.isNotEmpty
        ? buckets[sport]
        : null;
    if (bucket is Map<String, dynamic>) {
      final count = (bucket['count'] as num?)?.toInt() ?? 0;
      if (count > 0) {
        final avg = (bucket['average'] as num?)?.toDouble();
        if (avg != null) return avg;
      }
    }
    return (json['host_rating'] as num?)?.toDouble() ??
        (json['hostRating'] as num?)?.toDouble();
  }

  /// Real hosted-games count from `hostProfile.hostedCount`
  /// (falling back to `activitiesCount`, then legacy flat fields).
  static int _hostGamesFor(Map<String, dynamic> json) {
    final profile = json['hostProfile'];
    final counts = profile is Map<String, dynamic>
        ? ((profile['hostedCount'] as num?)?.toInt() ??
            (profile['activitiesCount'] as num?)?.toInt())
        : null;
    return counts ??
        (json['host_games_count'] as num?)?.toInt() ??
        (json['hostGamesCount'] as num?)?.toInt() ??
        0;
  }

  static ActivityStatus _statusFromString(String? s) => switch (s) {
    'available' => ActivityStatus.available,
    'almostFull' || 'almost_full' => ActivityStatus.almostFull,
    'open' => ActivityStatus.available,
    'full' => ActivityStatus.full,
    'joined' => ActivityStatus.joined,
    'hosted' => ActivityStatus.hosted,
    'past' || 'cancelled' || 'completed' || 'removed' => ActivityStatus.past,
    _ => ActivityStatus.available,
  };
}

enum ActivityStatus { available, almostFull, full, joined, hosted, past }
