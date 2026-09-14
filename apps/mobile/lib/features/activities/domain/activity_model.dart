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

  /// Host's average rating (0–5) and the number of games they've hosted —
  /// shown as "★ 4.8 (32 games)" on the discovery card's social row.
  final double hostRating;
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
    this.hostRating = 4.8,
    this.hostGamesCount = 32,
    this.vibeTags = const ['Friendly people', 'Great vibes'],
    this.isParticipant = false,
    this.isHost = false,
    this.mySwipeDecision,
    this.hostId = '',
    this.latitude,
    this.longitude,
    this.joinPolicy = 'open',
    this.joinRequestStatus,
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

  ActivityModel copyWith({
    ActivityStatus? status,
    int? participantCount,
    bool? isParticipant,
    bool? isHost,
    String? mySwipeDecision,
    String? hostId,
    double? distanceKm,
    double? latitude,
    double? longitude,
    String? joinPolicy,
    String? joinRequestStatus,
  }) {
    return ActivityModel(
      id: id,
      title: title,
      sportType: sportType,
      description: description,
      location: location,
      addressLine: addressLine,
      distanceKm: distanceKm ?? this.distanceKm,
      dateTime: dateTime,
      skillLevel: skillLevel,
      capacity: capacity,
      participantCount: participantCount ?? this.participantCount,
      hostName: hostName,
      coverImageUrl: coverImageUrl,
      status: status ?? this.status,
      durationMinutes: durationMinutes,
      isPaid: isPaid,
      hostRating: hostRating,
      hostGamesCount: hostGamesCount,
      vibeTags: vibeTags,
      isParticipant: isParticipant ?? this.isParticipant,
      isHost: isHost ?? this.isHost,
      mySwipeDecision: mySwipeDecision ?? this.mySwipeDecision,
      hostId: hostId ?? this.hostId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      joinPolicy: joinPolicy ?? this.joinPolicy,
      joinRequestStatus: joinRequestStatus ?? this.joinRequestStatus,
    );
  }

  bool get isFull => participantCount >= capacity;
  bool get isAlmostFull => participantCount >= (capacity * 0.8).ceil();

  int get spotsLeft => capacity - participantCount;

  /// True when newcomers must be approved by the host instead of
  /// joining instantly.
  bool get requiresApproval => joinPolicy == 'approval';

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

    final start = DateTime.tryParse(startRaw ?? '') ?? DateTime.now();
    final end = endRaw == null ? null : DateTime.tryParse(endRaw);

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
    // `joined`, regardless of lifecycle.
    var status = _statusFromString(json['status'] as String?);
    if (isHost) {
      status = ActivityStatus.hosted;
    } else if (isParticipant) {
      status = ActivityStatus.joined;
    }

    return ActivityModel(
      id: json['id']?.toString() ?? json['activityId']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      sportType: json['sportType'] as String? ?? json['sport_type'] as String? ?? '',
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
      isPaid: json['is_paid'] as bool? ?? false,
      hostRating: (json['host_rating'] as num?)?.toDouble() ?? 4.8,
      hostGamesCount: (json['host_games_count'] as num?)?.toInt() ?? 0,
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
    );
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
