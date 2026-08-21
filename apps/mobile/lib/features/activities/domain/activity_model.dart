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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'sportType': sportType,
      'description': description,
      'location': location,
      'addressLine': addressLine,
      'distanceKm': distanceKm,
      'dateTime': dateTime.toIso8601String(),
      'skillLevel': skillLevel,
      'capacity': capacity,
      'participantCount': participantCount,
      'hostName': hostName,
      'coverImageUrl': coverImageUrl,
      'status': status.index,
      'durationMinutes': durationMinutes,
      'isPaid': isPaid,
      'hostRating': hostRating,
      'hostGamesCount': hostGamesCount,
      'vibeTags': vibeTags,
    };
  }

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sportType: json['sportType'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      addressLine: json['addressLine'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      dateTime: DateTime.parse(
        json['dateTime'] as String? ?? DateTime.now().toIso8601String(),
      ),
      skillLevel: json['skillLevel'] as String? ?? '',
      capacity: json['capacity'] as int? ?? 10,
      participantCount: json['participantCount'] as int? ?? 0,
      hostName: json['hostName'] as String? ?? '',
      coverImageUrl: json['coverImageUrl'] as String?,
      status: ActivityStatus.values[json['status'] as int? ?? 0],
      durationMinutes: json['durationMinutes'] as int? ?? 120,
      isPaid: json['isPaid'] as bool? ?? false,
      hostRating: (json['hostRating'] as num?)?.toDouble() ?? 4.8,
      hostGamesCount: json['hostGamesCount'] as int? ?? 32,
      vibeTags:
          (json['vibeTags'] as List?)?.map((e) => e.toString()).toList() ??
          const ['Friendly people', 'Great vibes'],
    );
  }
}

enum ActivityStatus { available, almostFull, full, joined, hosted, past }
