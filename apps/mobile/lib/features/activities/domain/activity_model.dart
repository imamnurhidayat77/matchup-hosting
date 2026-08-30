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

  ActivityModel copyWith({ActivityStatus? status, int? participantCount}) {
    return ActivityModel(
      id: id,
      title: title,
      sportType: sportType,
      description: description,
      location: location,
      addressLine: addressLine,
      distanceKm: distanceKm,
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
    );
  }

  bool get isFull => participantCount >= capacity;
  bool get isAlmostFull => participantCount >= (capacity * 0.8).ceil();

  int get spotsLeft => capacity - participantCount;

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
    };
  }

  /// Deserialises from the API wire format (snake_case).
  ///
  /// All [RemoteActivityRepository] methods call this instead of maintaining
  /// their own private `_parse` — one parsing path, one place to update.
  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      sportType: json['sport_type'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      addressLine: json['address_line'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      dateTime: DateTime.tryParse(
            json['date_time'] as String? ?? '',
          ) ??
          DateTime.now(),
      skillLevel: json['skill_level'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 10,
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      hostName: json['host_name'] as String? ?? '',
      coverImageUrl: json['cover_image_url'] as String?,
      status: _statusFromString(json['status'] as String?),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 120,
      isPaid: json['is_paid'] as bool? ?? false,
      hostRating: (json['host_rating'] as num?)?.toDouble() ?? 4.8,
      hostGamesCount: (json['host_games_count'] as num?)?.toInt() ?? 0,
      vibeTags:
          (json['vibe_tags'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  static ActivityStatus _statusFromString(String? s) => switch (s) {
    'available' => ActivityStatus.available,
    'almostFull' || 'almost_full' => ActivityStatus.almostFull,
    'full' => ActivityStatus.full,
    'joined' => ActivityStatus.joined,
    'hosted' => ActivityStatus.hosted,
    'past' => ActivityStatus.past,
    _ => ActivityStatus.available,
  };
}

enum ActivityStatus { available, almostFull, full, joined, hosted, past }
